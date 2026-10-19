#if canImport(AppKit)
import Foundation
import Jobs
import Capabilities

/// What the user dropped onto a petal.
public enum EngineOperation {
    case convert(target: String)
    case tool(id: String, options: ToolOptions)
}

/// Single entry point for every M1 conversion and tool. For each input: reserve the output name
/// (NameAllocator), write to a hidden temp file beside it, then atomically move it onto the placeholder.
public enum Engine {
    /// HUD title, e.g. "Converting to PNG", "Compressing 3 videos" (spec mockup 07).
    public static func title(for op: EngineOperation, items: [URL]) -> String {
        let n = items.count
        switch op {
        case .convert(let t):
            return n > 1 ? "Converting \(n) files to \(Formats.label(t))" : "Converting to \(Formats.label(t))"
        case .tool(let id, _):
            let verb: String = [
                "compress": "Compressing", "removeMetadata": "Removing metadata from", "cropImage": "Cropping",
                "trimVideo": "Trimming", "trimAudio": "Trimming", "muteVideo": "Removing audio from", "extractArchive": "Extracting",
            ][id] ?? CapabilityRegistry.name(forTool: id)
            guard n > 1 else { return verb.replacingOccurrences(of: " from", with: "") }
            return "\(verb) \(n) \(noun(for: items))"
        }
    }

    static func noun(for items: [URL]) -> String {
        let fams = Set(items.compactMap { Formats.format(of: $0).flatMap(Formats.family(of:)) })
        guard fams.count == 1, let f = fams.first else { return "files" }
        switch f {
        case .image: return "images"
        case .video: return "videos"
        case .audio: return "audio files"
        case .pdf: return "PDFs"
        case .archive: return "archives"
        case .subtitle: return "subtitle files"
        default: return "files"
        }
    }

    public static func perform(_ op: EngineOperation, items: [URL], context: JobContext) async throws -> [URL] {
        var outputs: [URL] = []
        var failures: [(String, JobFailure)] = []
        for (i, input) in items.enumerated() {
            try context.checkCancelled()
            let child = context.child(index: i, count: items.count, item: input.lastPathComponent)
            do {
                outputs.append(try await performOne(op, input: input, context: child))
            } catch is JobCancelled {
                throw JobCancelled()
            } catch let f as JobFailure {
                if context.isCancelled { throw JobCancelled() }
                failures.append((input.lastPathComponent, f))
            } catch {
                if context.isCancelled { throw JobCancelled() }
                failures.append((input.lastPathComponent, JobFailure(error.localizedDescription, details: String(describing: error))))
            }
        }
        context.report(1)
        if let (name, f) = failures.first {
            let details = failures.map { "\($0.0): \($0.1.message)\n\($0.1.details)" }.joined(separator: "\n\n")
            if outputs.isEmpty { throw JobFailure(f.message, details: details) }
            throw JobFailure("Saved \(outputs.count) of \(items.count). Couldn't process “\(name)”\(failures.count > 1 ? " and \(failures.count - 1) more" : "").", details: details)
        }
        return outputs
    }

    static func performOne(_ op: EngineOperation, input: URL, context: JobContext) async throws -> URL {
        let dir = input.deletingLastPathComponent()
        let (stem, ext): (String, String?)
        switch op {
        case .convert(let t): (stem, ext) = Naming.conversionStem(source: input, target: t)
        case .tool(let id, _): (stem, ext) = Naming.toolStem(source: input, tool: id)
        }
        let dest = try await NameAllocator.shared.reserve(in: dir, stem: stem, ext: ext)
        let tmp = SafeWrite.tempURL(for: dest)
        do {
            if ext == nil { try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: false) }
            try await run(op, input: input, output: tmp, context: context)
            try context.checkCancelled()
            guard FileManager.default.fileExists(atPath: tmp.path) else { throw JobFailure("The engine produced no output.") }
            try SafeWrite.commit(tmp, to: dest)
            return dest
        } catch {
            SafeWrite.discard(tmp)
            await NameAllocator.shared.release(dest)
            throw error
        }
    }

    static func run(_ op: EngineOperation, input: URL, output: URL, context: JobContext) async throws {
        let fmt = Formats.format(of: input) ?? ""
        let family = Formats.family(of: fmt)
        switch op {
        case .convert(let target):
            switch family {
            case .image: try await ImageEngine.convert(input, to: target, output: output, context: context)
            case .audio: try await AudioEngine.convert(input, to: target, output: output, context: context)
            case .video: try await VideoEngine.convert(input, to: target, output: output, context: context)
            case .subtitle: try Subtitles.convert(input: input, target: target, output: output)
            case .archive: try await Archives.convert(input, target: target, output: output, context: context)
            default: throw JobFailure("Converting \(Formats.label(fmt)) files isn't available yet.")
            }
        case .tool(let id, let options):
            switch (id, family, options) {
            case ("compress", .image?, .compress(let o)):
                try await ImageEngine.compressedData(input, options: o, context: context).write(to: output)
            case ("compress", .audio?, .compress(let o)):
                try await AudioEngine.compress(input, options: o, output: output, context: context)
            case ("compress", .video?, .compress(let o)):
                try await VideoEngine.compress(input, options: o, output: output, context: context)
            case ("compress", .pdf?, .compress(let o)):
                try PDFTools.compress(input, options: o, output: output)
            case ("removeMetadata", .image?, _), ("removeMetadata", .video?, _) where fmt == "gif" || family == .image:
                try await ImageEngine.removeMetadata(input, output: output, context: context)
            case ("removeMetadata", .audio?, _), ("removeMetadata", .video?, _):
                let info = try await FFmpeg.probe(input, context: context)
                try await FFmpeg.run(input: input, output: output, args: try FFmpeg.recipeArgs("tool.removeMetadata.av", source: info),
                                     duration: info.duration, context: context) { context.report($0) }
            case ("removeMetadata", .pdf?, _):
                try PDFTools.removeMetadata(input, output: output)
            case ("cropImage", .image?, .crop(let o)):
                try await ImageEngine.crop(input, options: o, output: output, context: context)
            case ("trimVideo", .video?, .trim(let o)):
                try await VideoEngine.trim(input, options: o, output: output, context: context)
            case ("trimAudio", .audio?, .trim(let o)):
                try await AudioEngine.trim(input, options: o, output: output, context: context)
            case ("muteVideo", .video?, _):
                try await VideoEngine.mute(input, output: output, context: context)
            case ("extractArchive", .archive?, _):
                try await Archives.extract(input, into: output, context: context)
            default:
                throw JobFailure("\(CapabilityRegistry.name(forTool: id)) isn't available for \(Formats.label(fmt)) files.")
            }
        }
    }

    /// Metadata rows for the Metadata window.
    public static func readMetadata(_ url: URL) async -> [(group: String, key: String, value: String)] {
        let fmt = Formats.format(of: url) ?? ""
        switch Formats.family(of: fmt) {
        case .image?: return ImageEngine.readMetadata(url)
        case .pdf?: return PDFTools.readMetadata(url)
        default:
            if fmt == "gif" { return ImageEngine.readMetadata(url) }
            guard let info = try? await FFmpeg.probe(url) else { return [] }
            var rows = info.tags.sorted { $0.key < $1.key }.map { ("File", $0.key, $0.value) }
            for (i, s) in info.streams.enumerated() {
                rows += s.tags.sorted { $0.key < $1.key }.map { ("Track \(i + 1) (\(s.type))", $0.key, $0.value) }
            }
            return rows
        }
    }
}
#endif
