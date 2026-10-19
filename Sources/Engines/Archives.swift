import Foundation
import Jobs

/// ZIP / TAR / GZIP (tar.gz) / RAR (read-only) via the bundled libarchive `bsdtar`.
/// bsdtar refuses absolute paths and `..` components unless -P is given, so extraction stays inside the target.
public enum Archives {
    public static func extract(_ archive: URL, into dir: URL, context: JobContext?) async throws {
        let tar = try ToolLocator.require("bsdtar")
        let r = try await ProcessRunner.run(tar, ["-x", "-f", archive.path, "-C", dir.path], context: context)
        guard r.status == 0 else {
            throw JobFailure("Morph couldn't open “\(archive.lastPathComponent)”. It may be damaged, encrypted or an unsupported variant.", details: r.stderrTail)
        }
    }

    /// Repacks `archive` as `target` (zip | tar | gz) into `output`.
    public static func convert(_ archive: URL, target: String, output: URL, context: JobContext?) async throws {
        let tar = try ToolLocator.require("bsdtar")
        let work = output.deletingLastPathComponent().appendingPathComponent(".morph-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: work) }
        try await extract(archive, into: work, context: context)
        context?.report(0.5)
        let entries = try FileManager.default.contentsOfDirectory(atPath: work.path).sorted()
        guard !entries.isEmpty else { throw JobFailure("“\(archive.lastPathComponent)” is empty.") }
        var args: [String]
        switch target {
        case "zip": args = ["--format", "zip", "-c", "-f", output.path]
        case "tar": args = ["--format", "pax", "-c", "-f", output.path]
        case "gz": args = ["--format", "pax", "-z", "-c", "-f", output.path]
        default: throw JobFailure("Archives can't be converted to \(target.uppercased()).")
        }
        args += ["-C", work.path, "--"] + entries
        let r = try await ProcessRunner.run(tar, args, context: context)
        guard r.status == 0 else {
            throw JobFailure("Morph couldn't create the \(target == "gz" ? "GZIP" : target.uppercased()) archive. The original is unchanged.", details: r.stderrTail)
        }
    }
}
