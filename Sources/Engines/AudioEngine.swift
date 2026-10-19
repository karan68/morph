#if canImport(AudioToolbox) && canImport(AVFoundation)
import Foundation
import AudioToolbox
import AVFoundation
import Jobs
import Capabilities

/// Audio conversions and tools (spec §7.2): AudioToolbox encodes WAV/AIFF/FLAC/M4A natively;
/// MP3/OGG/Opus/WMA (and decoding of OGG/Opus/WMA inputs) go through the bundled LGPL FFmpeg.
public enum AudioEngine {
    /// Inputs Core Audio can decode, and outputs it can encode (verified with afconvert on macOS 26.7, spec §7.2).
    static let nativeInputs: Set<String> = ["mp3", "m4a", "wav", "flac", "aiff"]
    static let nativeOutputs: Set<String> = ["wav", "aiff", "flac", "m4a"]

    public enum Path: String { case audioToolbox, ffmpeg }

    /// Converts and returns which engine did the work (the CLI/golden tests report it).
    @discardableResult
    public static func convert(_ input: URL, to format: String, output: URL, context: JobContext?) async throws -> Path {
        let inFmt = Formats.format(of: input) ?? ""
        if nativeInputs.contains(inFmt), nativeOutputs.contains(format) {
            do {
                try nativeConvert(input, to: format, output: output, context: context)
                return .audioToolbox
            } catch is JobCancelled {
                throw JobCancelled()
            } catch {
                // Fall back to FFmpeg (e.g. an encoder unavailable on this macOS version).
                try? FileManager.default.removeItem(at: output)
            }
        }
        let info = try await FFmpeg.probe(input, context: context)
        guard info.audio != nil else { throw JobFailure("“\(input.lastPathComponent)” has no audio track.") }
        let key = Formats.family(of: inFmt) == .video ? "video.\(format)" : "audio.\(format)"
        try await FFmpeg.run(input: input, output: output, args: try FFmpeg.recipeArgs(key, source: info),
                             duration: info.duration, context: context) { context?.report($0) }
        return .ffmpeg
    }

    // MARK: Native (ExtAudioFile)

    static func check(_ status: OSStatus, _ what: String) throws {
        guard status == noErr else { throw JobFailure("Core Audio couldn't \(what) (error \(status)).") }
    }

    static func nativeConvert(_ input: URL, to format: String, output: URL, context: JobContext?) throws {
        var inRef: ExtAudioFileRef?
        try check(ExtAudioFileOpenURL(input as CFURL, &inRef), "open the file")
        guard let inFile = inRef else { throw JobFailure("Core Audio couldn't open the file.") }
        defer { ExtAudioFileDispose(inFile) }

        var inASBD = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        try check(ExtAudioFileGetProperty(inFile, kExtAudioFileProperty_FileDataFormat, &size, &inASBD), "read the format")
        var totalFrames: Int64 = 0
        size = UInt32(MemoryLayout<Int64>.size)
        _ = ExtAudioFileGetProperty(inFile, kExtAudioFileProperty_FileLengthFrames, &size, &totalFrames)

        let sr = inASBD.mSampleRate
        let ch = max(1, inASBD.mChannelsPerFrame)
        let deep = inASBD.mFormatID == kAudioFormatLinearPCM ? inASBD.mBitsPerChannel > 16
            : (inASBD.mFormatID == kAudioFormatFLAC || inASBD.mFormatID == kAudioFormatAppleLossless) && inASBD.mFormatFlags >= kAppleLosslessFormatFlag_20BitSourceData
        let bits: UInt32 = deep ? 24 : 16

        var out = AudioStreamBasicDescription()
        var fileType: AudioFileTypeID
        switch format {
        case "wav", "aiff":
            fileType = format == "wav" ? kAudioFileWAVEType : kAudioFileAIFFType
            out.mSampleRate = sr
            out.mFormatID = kAudioFormatLinearPCM
            out.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked | (format == "aiff" ? kAudioFormatFlagIsBigEndian : 0)
            out.mChannelsPerFrame = ch
            out.mBitsPerChannel = bits
            out.mBytesPerFrame = ch * bits / 8
            out.mFramesPerPacket = 1
            out.mBytesPerPacket = out.mBytesPerFrame
        case "flac":
            fileType = kAudioFileFLACType
            out.mSampleRate = sr
            out.mFormatID = kAudioFormatFLAC
            // Per CoreAudioBaseTypes.h: "the flags indicate the bit depth of the source material".
            out.mFormatFlags = deep ? kAppleLosslessFormatFlag_24BitSourceData : kAppleLosslessFormatFlag_16BitSourceData
            out.mChannelsPerFrame = ch
        case "m4a":
            fileType = kAudioFileM4AType
            out.mSampleRate = min(sr, 48_000)
            out.mFormatID = kAudioFormatMPEG4AAC
            out.mChannelsPerFrame = ch
        default:
            throw JobFailure("Unsupported native output \(format).")
        }
        if out.mFormatID != kAudioFormatLinearPCM {
            var s = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
            try check(AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, nil, &s, &out), "describe the output format")
        }

        var outRef: ExtAudioFileRef?
        try check(ExtAudioFileCreateWithURL(output as CFURL, fileType, &out, nil, AudioFileFlags.eraseFile.rawValue, &outRef), "create the output file")
        guard let outFile = outRef else { throw JobFailure("Core Audio couldn't create the output file.") }
        var disposed = false
        defer { if !disposed { ExtAudioFileDispose(outFile) } }

        var client = AudioStreamBasicDescription(mSampleRate: sr, mFormatID: kAudioFormatLinearPCM,
                                                 mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
                                                 mBytesPerPacket: 4 * ch, mFramesPerPacket: 1, mBytesPerFrame: 4 * ch,
                                                 mChannelsPerFrame: ch, mBitsPerChannel: 32, mReserved: 0)
        let asbdSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        try check(ExtAudioFileSetProperty(inFile, kExtAudioFileProperty_ClientDataFormat, asbdSize, &client), "set the read format")
        try check(ExtAudioFileSetProperty(outFile, kExtAudioFileProperty_ClientDataFormat, asbdSize, &client), "set the write format")

        if format == "m4a" {
            var conv: AudioConverterRef?
            var cs = UInt32(MemoryLayout<AudioConverterRef?>.size)
            if ExtAudioFileGetProperty(outFile, kExtAudioFileProperty_AudioConverter, &cs, &conv) == noErr, let conv = conv {
                var rate: UInt32 = 256_000
                AudioConverterSetProperty(conv, kAudioConverterEncodeBitRate, UInt32(MemoryLayout<UInt32>.size), &rate)
                var nilConfig: CFPropertyList?
                ExtAudioFileSetProperty(outFile, kExtAudioFileProperty_ConverterConfig, UInt32(MemoryLayout<CFPropertyList?>.size), &nilConfig)
            }
        }

        let framesPerRead: UInt32 = 8192
        let buffer = UnsafeMutableRawPointer.allocate(byteCount: Int(framesPerRead * 4 * ch), alignment: 16)
        defer { buffer.deallocate() }
        var done: Int64 = 0
        while true {
            try context?.checkCancelled()
            var list = AudioBufferList(mNumberBuffers: 1, mBuffers: AudioBuffer(mNumberChannels: ch, mDataByteSize: framesPerRead * 4 * ch, mData: buffer))
            var frames = framesPerRead
            try check(ExtAudioFileRead(inFile, &frames, &list), "read audio")
            if frames == 0 { break }
            try check(ExtAudioFileWrite(outFile, frames, &list), "write audio")
            done += Int64(frames)
            if totalFrames > 0 { context?.report(Double(done) / Double(totalFrames)) }
        }
        let status = ExtAudioFileDispose(outFile)
        disposed = true
        try check(status, "finish the file")
    }

    // MARK: Tools

    /// Compress: lower bitrate for lossy formats; WAV → FLAC; FLAC at maximum compression (lossless).
    public static func compress(_ input: URL, options: CompressOptions, output: URL, context: JobContext?) async throws {
        let fmt = Formats.format(of: input) ?? ""
        let info = try await FFmpeg.probe(input, context: context)
        let original = (try? FileManager.default.attributesOfItem(atPath: input.path)[.size] as? NSNumber)?.int64Value ?? 0
        let duration = info.duration ?? 0
        var args = ["-vn", "-map_metadata", options.keepMetadata ? "0" : "-1"]
        let srcBitrate = info.audio?.bitRate ?? info.bitRate ?? 192_000
        func lossyKbps() -> Int {
            if let t = options.targetSize(original: original), duration > 0 {
                return max(24, Int(Double(t) * 8 / duration / 1000 * 0.97))
            }
            return max(32, Int(Double(srcBitrate) * options.presetBitrateRatio / 1000))
        }
        switch fmt {
        case "mp3": args += ["-c:a", "libmp3lame", "-b:a", "\(lossyKbps())k"]
        case "m4a": args += ["-c:a", "aac", "-b:a", "\(lossyKbps())k", "-movflags", "+faststart"]
        case "wav", "flac":
            args += ["-c:a", "flac", "-compression_level", "12"]
            if options.preset != .balanced, (info.audio?.bitsPerSample ?? 16) > 16 { args += ["-sample_fmt", "s16"] }
            if options.preset == .smallest { args += ["-ar", "44100"] }
        default: throw JobFailure("Compress isn't available for \(fmt.uppercased()) audio.")
        }
        try await FFmpeg.run(input: input, output: output, args: args, duration: info.duration, context: context) { context?.report($0) }
    }

    /// Trim to [start, end]. M4A: AVFoundation passthrough (no re-encode); MP3: stream copy (frame-accurate, ~26 ms);
    /// WAV/FLAC: sample-accurate lossless re-encode.
    public static func trim(_ input: URL, options: TrimOptions, output: URL, context: JobContext?) async throws {
        let fmt = Formats.format(of: input) ?? ""
        guard options.end > options.start else { throw JobFailure("The end must be after the start.") }
        if fmt == "m4a" {
            try await AVExport.passthrough(input, output: output, fileType: .m4a, range: options, context: context)
            return
        }
        let info = try await FFmpeg.probe(input, context: context)
        var args = ["-ss", String(format: "%.3f", options.start), "-to", String(format: "%.3f", options.end), "-map", "0:a", "-map_metadata", "0"]
        switch fmt {
        case "mp3": args += ["-c:a", "copy"]
        case "wav": args += ["-c:a", (info.audio?.bitsPerSample ?? 16) > 16 ? "pcm_s24le" : "pcm_s16le"]
        case "flac": args += ["-c:a", "flac"]
        default: throw JobFailure("Trim isn't available for \(fmt.uppercased()).")
        }
        try await FFmpeg.run(input: input, output: output, args: args, duration: options.end - options.start, context: context) { context?.report($0) }
    }

    /// Peak envelope (0…1) in `buckets` bins, decoded by FFmpeg (mono, 2 kHz float).
    public static func waveform(_ input: URL, buckets: Int) async throws -> (peaks: [Float], duration: Double) {
        let ffmpeg = try ToolLocator.require("ffmpeg")
        let r = try await ProcessRunner.run(ffmpeg, ["-hide_banner", "-nostdin", "-loglevel", "error", "-i", input.path,
                                                     "-vn", "-ac", "1", "-ar", "2000", "-f", "f32le", "-"])
        guard r.status == 0 else { throw JobFailure("Morph couldn't read the audio.", details: r.stderrTail) }
        let samples: [Float] = r.stdout.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
        let duration = Double(samples.count) / 2000
        guard !samples.isEmpty, buckets > 0 else { return ([], duration) }
        let per = max(1, samples.count / buckets)
        var peaks: [Float] = []
        peaks.reserveCapacity(buckets)
        var i = 0
        while i < samples.count {
            let end = min(samples.count, i + per)
            var m: Float = 0
            for j in i..<end { m = max(m, abs(samples[j])) }
            peaks.append(min(1, m))
            i = end
        }
        return (peaks, duration)
    }

    /// Start/end of non-silent audio (threshold −50 dBFS) from a peak envelope, for "Trim silent ends automatically".
    public static func nonSilentRange(peaks: [Float], duration: Double, thresholdDB: Float = -50) -> TrimOptions {
        let t = powf(10, thresholdDB / 20)
        guard let first = peaks.firstIndex(where: { $0 > t }), let last = peaks.lastIndex(where: { $0 > t }), !peaks.isEmpty else {
            return TrimOptions(start: 0, end: duration)
        }
        let step = duration / Double(peaks.count)
        return TrimOptions(start: max(0, Double(first) * step), end: min(duration, Double(last + 1) * step))
    }
}

/// AVAssetExportSession helpers shared by audio and video tools.
public enum AVExport {
    public static func passthrough(_ input: URL, output: URL, fileType: AVFileType, range: TrimOptions?, context: JobContext?) async throws {
        let asset = AVURLAsset(url: input)
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
            throw JobFailure("macOS can't export this file without re-encoding.")
        }
        try await export(session, output: output, fileType: fileType, range: range, context: context)
    }

    public static func export(_ session: AVAssetExportSession, output: URL, fileType: AVFileType, range: TrimOptions?, context: JobContext?) async throws {
        try? FileManager.default.removeItem(at: output)
        session.outputURL = output
        session.outputFileType = fileType
        if let r = range {
            session.timeRange = CMTimeRange(start: CMTime(seconds: r.start, preferredTimescale: 600),
                                            end: CMTime(seconds: r.end, preferredTimescale: 600))
        }
        context?.onCancel { session.cancelExport() }
        let poll = Task {
            while !Task.isCancelled {
                context?.report(Double(session.progress))
                try? await Task.sleep(nanoseconds: 150_000_000)
            }
        }
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
            session.exportAsynchronously { c.resume() }
        }
        poll.cancel()
        try context?.checkCancelled()
        guard session.status == .completed else {
            throw JobFailure("macOS couldn't export the file.", details: session.error.map { String(describing: $0) } ?? "status \(session.status.rawValue)")
        }
    }
}
#endif
