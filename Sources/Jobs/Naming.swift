import Foundation
import Capabilities

/// Output naming rules (spec §4.3):
/// conversions `<base>.<ext>`, tools `<base> <Suffix>.<ext>`, collisions append ` 2`, ` 3`…
public enum Naming {
    /// Name without its extension; `.tar.gz` / `.tgz` are stripped as one extension.
    public static func baseName(_ fileName: String) -> String {
        let lower = fileName.lowercased()
        for ext in [".tar.gz", ".tgz"] where lower.hasSuffix(ext) && lower.count > ext.count {
            return String(fileName.dropLast(ext.count))
        }
        guard let dot = fileName.lastIndex(of: "."), dot != fileName.startIndex else { return fileName }
        return String(fileName[..<dot])
    }

    /// Tool id → output suffix (spec §3.2).
    public static let toolSuffix: [String: String] = [
        "compress": "Compressed", "removeMetadata": "No Metadata", "editImage": "Edited", "annotateImage": "Annotated",
        "frameImage": "Background", "cropImage": "Cropped", "redactImage": "Redacted", "cropVideo": "Cropped",
        "normalizeAudio": "Normalized", "muteVideo": "Muted", "trimVideo": "Trimmed", "trimAudio": "Trimmed",
        "redactAudio": "Bleeped", "videoSnapshots": "Snapshot", "splitVideo": "Clips", "splitPDF": "Pages",
        "organizePDF": "Organized", "redactVideo": "Redacted", "extractArchive": "Extracted", "audioToVideo": "Visualizer",
    ]

    /// Output format for a tool applied to `format`. "folder" means the tool writes a new folder.
    public static func toolOutputFormat(tool: String, inputFormat: String) -> String {
        switch tool {
        case "compress": return inputFormat == "wav" ? "flac" : inputFormat
        case "annotateImage", "videoSnapshots": return "png"
        case "splitVideo", "splitPDF", "extractArchive": return "folder"
        case "organizePDF": return "pdf"
        case "audioToVideo": return "mp4"
        default: return inputFormat
        }
    }

    /// Candidate (stem, extension) for a conversion. extension nil = folder.
    public static func conversionStem(source: URL, target: String) -> (stem: String, ext: String?) {
        (baseName(source.lastPathComponent), Formats.fileExtension(for: target))
    }

    public static func toolStem(source: URL, tool: String) -> (stem: String, ext: String?) {
        let base = baseName(source.lastPathComponent)
        let out = toolOutputFormat(tool: tool, inputFormat: Formats.format(of: source) ?? source.pathExtension.lowercased())
        let suffix = toolSuffix[tool] ?? "Edited"
        return ("\(base) \(suffix)", out == "folder" ? nil : Formats.fileExtension(for: out))
    }

    /// `stem.ext`, then `stem 2.ext`, `stem 3.ext`… (folders when ext is nil).
    public static func candidate(stem: String, ext: String?, attempt: Int) -> String {
        let s = attempt <= 1 ? stem : "\(stem) \(attempt)"
        guard let ext = ext else { return s }
        return "\(s).\(ext)"
    }
}

public enum NameAllocatorError: Error, LocalizedError {
    case notWritable(URL)
    case exhausted(String)
    public var errorDescription: String? {
        switch self {
        case .notWritable(let dir): return "Morph can't save into “\(dir.lastPathComponent)”. The folder isn't writable."
        case .exhausted(let stem): return "Couldn't find a free name for “\(stem)”."
        }
    }
}

/// Serialized destination allocator (spec §4.3 "Name reservation").
/// Every reservation creates a zero-byte placeholder with O_CREAT|O_EXCL (or mkdir for folders),
/// so two jobs — even in different processes — can never be handed the same name.
public actor NameAllocator {
    public static let shared = NameAllocator()
    public init() {}

    public func reserve(in directory: URL, stem: String, ext: String?) throws -> URL {
        for attempt in 1...9_999 {
            let url = directory.appendingPathComponent(Naming.candidate(stem: stem, ext: ext, attempt: attempt))
            if ext == nil {
                if mkdir(url.path, 0o755) == 0 { return url }
            } else {
                let fd = open(url.path, O_CREAT | O_EXCL | O_WRONLY, 0o644)
                if fd >= 0 { close(fd); return url }
            }
            switch errno {
            case EEXIST: continue
            case EACCES, EROFS, EPERM: throw NameAllocatorError.notWritable(directory)
            default: throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: [NSFilePathErrorKey: url.path])
            }
        }
        throw NameAllocatorError.exhausted(stem)
    }

    /// Removes a placeholder that was never filled (cancel / failure).
    public func release(_ url: URL) {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { return }
        if isDir.boolValue {
            if (try? FileManager.default.contentsOfDirectory(atPath: url.path))?.isEmpty == true { rmdir(url.path) }
        } else if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path), (attrs[.size] as? NSNumber)?.intValue == 0 {
            unlink(url.path)
        }
    }
}

/// Temp output beside the destination, then an atomic rename over *our own* placeholder (spec §4.3 "Write safety").
public enum SafeWrite {
    /// Hidden temp URL in the destination's folder, keeping the extension so encoders pick the right container.
    public static func tempURL(for destination: URL) -> URL {
        let name = destination.lastPathComponent
        let ext: String = name.lowercased().hasSuffix(".tar.gz") ? "tar.gz" : destination.pathExtension
        let tmp = ".morph-\(UUID().uuidString)" + (ext.isEmpty ? "" : ".\(ext)")
        return destination.deletingLastPathComponent().appendingPathComponent(tmp)
    }

    /// Moves `temp` onto the placeholder at `destination` atomically.
    public static func commit(_ temp: URL, to destination: URL) throws {
        if rename(temp.path, destination.path) != 0 {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: [NSFilePathErrorKey: destination.path])
        }
    }

    public static func discard(_ temp: URL) {
        try? FileManager.default.removeItem(at: temp)
    }
}
