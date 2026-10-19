import Foundation
import Jobs
import Capabilities

/// Subset of `ffprobe -show_format -show_streams -of json` used by engines and tests.
public struct MediaInfo {
    public struct Stream {
        public let type: String          // video | audio | subtitle | data
        public let codec: String
        public let width: Int?
        public let height: Int?
        public let bitRate: Int?
        public let bitsPerSample: Int?
        public let sampleFormat: String?
        public let tags: [String: String]
    }
    public let duration: Double?
    public let bitRate: Int?
    public let formatName: String
    public let streams: [Stream]
    public let tags: [String: String]

    public var video: Stream? { streams.first { $0.type == "video" } }
    public var audio: Stream? { streams.first { $0.type == "audio" } }

    /// Estimated video bitrate in bits/s: stream value, else container minus audio, else a resolution default.
    public var estimatedVideoBitRate: Int {
        if let b = video?.bitRate, b > 0 { return b }
        if let total = bitRate, total > 0 { return max(500_000, total - (audio?.bitRate ?? 128_000)) }
        let px = (video?.width ?? 1280) * (video?.height ?? 720)
        return max(1_000_000, px * 4)
    }
}

public enum FFmpeg {
    public static func probe(_ url: URL, context: JobContext? = nil) async throws -> MediaInfo {
        let ffprobe = try ToolLocator.require("ffprobe")
        let r = try await ProcessRunner.run(ffprobe, ["-v", "error", "-show_format", "-show_streams", "-of", "json", url.path], context: context)
        guard r.status == 0, let obj = try? JSONSerialization.jsonObject(with: r.stdout) as? [String: Any] else {
            throw JobFailure("Morph couldn't read “\(url.lastPathComponent)”. The file may be damaged or in an unsupported variant.", details: r.stderrTail)
        }
        return parse(obj)
    }

    static func parse(_ obj: [String: Any]) -> MediaInfo {
        func int(_ v: Any?) -> Int? { (v as? String).flatMap { Int($0) } ?? (v as? Int) }
        func dbl(_ v: Any?) -> Double? { (v as? String).flatMap { Double($0) } ?? (v as? Double) }
        func tags(_ v: Any?) -> [String: String] {
            ((v as? [String: Any]) ?? [:]).reduce(into: [:]) { $0[$1.key] = "\($1.value)" }
        }
        let fmt = obj["format"] as? [String: Any] ?? [:]
        let streams = (obj["streams"] as? [[String: Any]] ?? []).map { s in
            MediaInfo.Stream(type: s["codec_type"] as? String ?? "", codec: s["codec_name"] as? String ?? "",
                             width: int(s["width"]), height: int(s["height"]), bitRate: int(s["bit_rate"]),
                             bitsPerSample: int(s["bits_per_raw_sample"]) ?? int(s["bits_per_sample"]),
                             sampleFormat: s["sample_fmt"] as? String, tags: tags(s["tags"]))
        }
        return MediaInfo(duration: dbl(fmt["duration"]), bitRate: int(fmt["bit_rate"]),
                         formatName: fmt["format_name"] as? String ?? "", streams: streams, tags: tags(fmt["tags"]))
    }

    /// Runs `ffmpeg -i input [args] output` with progress parsed from `-progress pipe:1`.
    /// - Parameters:
    ///   - duration: seconds used to turn out_time into a fraction (nil = indeterminate).
    ///   - inputArgs: options placed before `-i` (e.g. `-ss`).
    public static func run(input: URL, output: URL, args: [String], inputArgs: [String] = [],
                           duration: Double?, context: JobContext?, progress: ((Double) -> Void)? = nil) async throws {
        let ffmpeg = try ToolLocator.require("ffmpeg")
        let full = ["-hide_banner", "-nostdin", "-y", "-nostats", "-progress", "pipe:1", "-loglevel", "error"]
            + inputArgs + ["-i", input.path] + args + [output.path]
        let r = try await ProcessRunner.run(ffmpeg, full, context: context, collectStdout: false) { line in
            guard let d = duration, d > 0, line.hasPrefix("out_time_us=") || line.hasPrefix("out_time_ms=") else { return }
            if let us = Double(line.split(separator: "=").last ?? "") { progress?(min(1, us / 1_000_000 / d)) }
        }
        guard r.status == 0 else {
            throw JobFailure("Morph couldn't convert “\(input.lastPathComponent)”. The original is unchanged.", details: r.stderrTail)
        }
    }

    /// Recipe args with placeholders resolved from the probed source.
    public static func recipeArgs(_ key: String, source: MediaInfo?) throws -> [String] {
        guard let recipe = FFmpegRecipes.all[key] else { throw JobFailure("Internal error: no recipe \(key).") }
        // 24-bit PCM out only when the source really carries more than 16 bits (e.g. 24-bit WAV/FLAC/AIFF).
        let a = source?.audio
        let deep = (a?.bitsPerSample ?? 0) > 16 || ["s32", "s32p"].contains(a?.sampleFormat ?? "")
        let vb = source.map { max(1_000_000, $0.estimatedVideoBitRate) } ?? 4_000_000
        return recipe.resolved([
            "{vbitrate}": "\(vb / 1000)k",
            "{pcm_le}": deep ? "pcm_s24le" : "pcm_s16le",
            "{pcm_be}": deep ? "pcm_s24be" : "pcm_s16be",
        ])
    }
}
