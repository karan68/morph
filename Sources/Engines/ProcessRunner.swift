import Foundation
import Jobs
import Capabilities

/// Locates bundled helper executables (ffmpeg, ffprobe, bsdtar).
/// App: Morph.app/Contents/Helpers. CLI/tests: $MORPH_TOOLS_DIR. Never falls back to tools on $PATH,
/// so tests exercise exactly the LGPL build that ships.
public enum ToolLocator {
    public static func url(for tool: String) -> URL? {
        var dirs: [URL] = []
        if let env = ProcessInfo.processInfo.environment["MORPH_TOOLS_DIR"], !env.isEmpty {
            dirs.append(URL(fileURLWithPath: env))
        }
        let main = Bundle.main.bundleURL
        dirs.append(main.appendingPathComponent("Contents/Helpers"))
        let exeDir = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath().deletingLastPathComponent()
        dirs.append(exeDir.appendingPathComponent("../Helpers").standardizedFileURL)
        for d in dirs {
            let u = d.appendingPathComponent(tool)
            if FileManager.default.isExecutableFile(atPath: u.path) { return u }
        }
        return nil
    }

    public static func require(_ tool: String) throws -> URL {
        guard let u = url(for: tool) else {
            throw JobFailure("Morph's \(tool) component is missing. Reinstall Morph.", details: "Searched MORPH_TOOLS_DIR, Contents/Helpers.")
        }
        return u
    }
}

public struct ProcessResult {
    public let status: Int32
    public let stdout: Data
    public let stderrTail: String
}

/// Runs a helper process asynchronously. Cancelling the job terminates the process.
public enum ProcessRunner {
    /// - Parameter onStdoutLine: called for each stdout line (used for `ffmpeg -progress pipe:1`).
    public static func run(_ exe: URL, _ args: [String], context: JobContext? = nil,
                           collectStdout: Bool = true,
                           onStdoutLine: ((String) -> Void)? = nil) async throws -> ProcessResult {
        try context?.checkCancelled()
        let p = Process()
        p.executableURL = exe
        p.arguments = args
        var env = ProcessInfo.processInfo.environment
        env["AV_LOG_FORCE_NOCOLOR"] = "1"
        p.environment = env
        let outPipe = Pipe(), errPipe = Pipe()
        p.standardOutput = outPipe
        p.standardError = errPipe
        p.standardInput = FileHandle.nullDevice

        final class Box: @unchecked Sendable {
            let lock = NSLock()
            var out = Data()
            var err = Data()
            var lineBuf = Data()
            func finish(restOut: Data, restErr: Data) -> (Data, Data) {
                lock.lock(); defer { lock.unlock() }
                out.append(restOut); err.append(restErr)
                return (out, err)
            }
        }
        let box = Box()
        outPipe.fileHandleForReading.readabilityHandler = { h in
            let d = h.availableData
            guard !d.isEmpty else { return }
            box.lock.lock()
            if collectStdout { box.out.append(d) }
            var lines: [String] = []
            if onStdoutLine != nil {
                box.lineBuf.append(d)
                while let nl = box.lineBuf.firstIndex(of: 0x0A) {
                    let line = box.lineBuf[box.lineBuf.startIndex..<nl]
                    lines.append(String(decoding: line, as: UTF8.self))
                    box.lineBuf.removeSubrange(box.lineBuf.startIndex...nl)
                }
            }
            box.lock.unlock()
            lines.forEach { onStdoutLine?($0) }
        }
        errPipe.fileHandleForReading.readabilityHandler = { h in
            let d = h.availableData
            guard !d.isEmpty else { return }
            box.lock.lock()
            box.err.append(d)
            if box.err.count > 64_000 { box.err.removeFirst(box.err.count - 32_000) }
            box.lock.unlock()
        }

        let status: Int32 = try await withCheckedThrowingContinuation { cont in
            p.terminationHandler = { proc in cont.resume(returning: proc.terminationStatus) }
            do { try p.run() } catch { cont.resume(throwing: error); return }
            context?.onCancel { if p.isRunning { p.terminate() } }
        }
        outPipe.fileHandleForReading.readabilityHandler = nil
        errPipe.fileHandleForReading.readabilityHandler = nil
        let restOut = outPipe.fileHandleForReading.readDataToEndOfFile()
        let restErr = errPipe.fileHandleForReading.readDataToEndOfFile()
        let (out, err) = box.finish(restOut: collectStdout ? restOut : Data(), restErr: restErr)
        try context?.checkCancelled()
        let tail = String(decoding: err.suffix(6_000), as: UTF8.self)
        return ProcessResult(status: status, stdout: out, stderrTail: tail)
    }
}
