#if canImport(AVFoundation)
import Foundation
import AVFoundation
import ImageIO
import Jobs
import Capabilities

/// Video conversions and tools (spec §7.2): MP4/MOV ↔ MP4/MOV via AVFoundation (passthrough when possible);
/// everything else via the bundled LGPL FFmpeg (H.264 via VideoToolbox, VP9/Opus, MPEG-4, WMV2, GIF palette).
public enum VideoEngine {
    static let avfoundationContainers: Set<String> = ["mp4", "mov"]

    public static func convert(_ input: URL, to format: String, output: URL, context: JobContext?) async throws {
        let inFmt = Formats.format(of: input) ?? ""
        if format == "mp3" {
            try await AudioEngine.convert(input, to: "mp3", output: output, context: context)
            return
        }
        if avfoundationContainers.contains(inFmt), avfoundationContainers.contains(format) {
            do {
                try await AVExport.passthrough(input, output: output, fileType: format == "mp4" ? .mp4 : .mov, range: nil, context: context)
                return
            } catch is JobCancelled {
                throw JobCancelled()
            } catch {
                try? FileManager.default.removeItem(at: output) // e.g. a codec MP4 can't carry: re-encode below
            }
        }
        let info = try await FFmpeg.probe(input, context: context)
        guard info.video != nil else { throw JobFailure("“\(input.lastPathComponent)” has no video track.") }
        try await FFmpeg.run(input: input, output: output, args: try FFmpeg.recipeArgs("video.\(format)", source: info),
                             duration: info.duration, context: context) { context?.report($0) }
    }

    /// Remove audio: stream copy without audio tracks (lossless).
    public static func mute(_ input: URL, output: URL, context: JobContext?) async throws {
        let info = try await FFmpeg.probe(input, context: context)
        try await FFmpeg.run(input: input, output: output, args: try FFmpeg.recipeArgs("tool.muteVideo", source: info),
                             duration: info.duration, context: context) { context?.report($0) }
    }

    /// Compress: H.264 (VideoToolbox) at a lower bitrate in the same container.
    public static func compress(_ input: URL, options: CompressOptions, output: URL, context: JobContext?) async throws {
        let fmt = Formats.format(of: input) ?? "mp4"
        let info = try await FFmpeg.probe(input, context: context)
        let original = (try? FileManager.default.attributesOfItem(atPath: input.path)[.size] as? NSNumber)?.int64Value ?? 0
        let duration = info.duration ?? 0
        let audioKbps = 128
        var videoKbps: Int
        if let t = options.targetSize(original: original), duration > 0 {
            videoKbps = Int(Double(t) * 8 * 0.95 / duration / 1000) - (info.audio != nil ? audioKbps : 0)
        } else {
            videoKbps = Int(Double(info.estimatedVideoBitRate) * options.presetBitrateRatio / 1000)
        }
        videoKbps = max(150, videoKbps)
        var filters = ["scale=trunc(iw/2)*2:trunc(ih/2)*2"]
        let cap = options.maxDimension.rawValue
        if cap > 0 {
            filters = ["scale='if(gt(iw,ih),min(\(cap),iw),-2)':'if(gt(iw,ih),-2,min(\(cap),ih))'", "scale=trunc(iw/2)*2:trunc(ih/2)*2"]
        }
        var args = ["-map", "0:v:0", "-map", "0:a?", "-vf", filters.joined(separator: ","),
                    "-c:v", "h264_videotoolbox", "-allow_sw", "1", "-b:v", "\(videoKbps)k", "-maxrate", "\(Int(Double(videoKbps) * 1.5))k",
                    "-bufsize", "\(videoKbps * 2)k", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "\(audioKbps)k",
                    "-map_metadata", options.keepMetadata ? "0" : "-1"]
        if fmt == "mp4" { args += ["-movflags", "+faststart"] }
        try await FFmpeg.run(input: input, output: output, args: args, duration: info.duration, context: context) { context?.report($0) }
    }

    /// How a trim will be performed, so the window can tell the user honestly.
    public enum TrimMethod { case losslessEditList, streamCopy, reencode }

    public static func trimMethod(for input: URL, start: Double) async -> TrimMethod {
        let fmt = Formats.format(of: input) ?? ""
        if avfoundationContainers.contains(fmt) { return .losslessEditList }
        if let kf = try? await keyframeTimes(input), kf.contains(where: { abs($0 - start) < 0.001 }) { return .streamCopy }
        return start < 0.001 ? .streamCopy : .reencode
    }

    /// MP4/MOV: AVFoundation passthrough with an edit list (frame-accurate, no re-encode).
    /// MKV: stream copy when the start is a keyframe, otherwise a full VideoToolbox re-encode of the range.
    public static func trim(_ input: URL, options: TrimOptions, output: URL, context: JobContext?) async throws {
        let fmt = Formats.format(of: input) ?? ""
        guard options.end > options.start else { throw JobFailure("The end must be after the start.") }
        if avfoundationContainers.contains(fmt) {
            try await AVExport.passthrough(input, output: output, fileType: fmt == "mp4" ? .mp4 : .mov, range: options, context: context)
            return
        }
        let method = await trimMethod(for: input, start: options.start)
        let info = try await FFmpeg.probe(input, context: context)
        let range = ["-ss", String(format: "%.3f", options.start), "-to", String(format: "%.3f", options.end)]
        if method == .streamCopy {
            try await FFmpeg.run(input: input, output: output, args: ["-map", "0", "-c", "copy"], inputArgs: range,
                                 duration: options.end - options.start, context: context) { context?.report($0) }
        } else {
            let args = range + (try FFmpeg.recipeArgs("video.mkv", source: info))
            try await FFmpeg.run(input: input, output: output, args: args, duration: options.end - options.start, context: context) { context?.report($0) }
        }
    }

    /// Keyframe timestamps of the first video stream (seconds).
    public static func keyframeTimes(_ input: URL) async throws -> [Double] {
        let ffprobe = try ToolLocator.require("ffprobe")
        let r = try await ProcessRunner.run(ffprobe, ["-v", "error", "-select_streams", "v:0", "-skip_frame", "nokey",
                                                      "-show_entries", "frame=pts_time", "-of", "csv=p=0", input.path])
        return String(decoding: r.stdout, as: UTF8.self).split(separator: "\n").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
    }

    /// One frame as an image (for filmstrips and MKV scrubbing, where AVFoundation can't decode).
    public static func frame(_ input: URL, at seconds: Double, maxWidth: Int) async throws -> CGImage? {
        let fmt = Formats.format(of: input) ?? ""
        if avfoundationContainers.contains(fmt) {
            let gen = AVAssetImageGenerator(asset: AVURLAsset(url: input))
            gen.appliesPreferredTrackTransform = true
            gen.maximumSize = CGSize(width: maxWidth, height: maxWidth)
            gen.requestedTimeToleranceBefore = .zero
            gen.requestedTimeToleranceAfter = .zero
            return try? gen.copyCGImage(at: CMTime(seconds: seconds, preferredTimescale: 600), actualTime: nil)
        }
        let ffmpeg = try ToolLocator.require("ffmpeg")
        let r = try await ProcessRunner.run(ffmpeg, ["-hide_banner", "-nostdin", "-loglevel", "error", "-ss", String(format: "%.3f", seconds),
                                                     "-i", input.path, "-frames:v", "1", "-vf", "scale='min(\(maxWidth),iw)':-2",
                                                     "-f", "image2pipe", "-c:v", "png", "-"])
        guard r.status == 0, let src = CGImageSourceCreateWithData(r.stdout as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(src, 0, nil)
    }

    public static func duration(_ input: URL) async throws -> Double {
        try await FFmpeg.probe(input).duration ?? 0
    }
}
#endif
