import AppKit
import Foundation
import Capabilities
import Engines

// `Morph --self-test`: used by CI on the signed .app bundle. Verifies the bundle launches, every helper
// executes with its bundled dylibs (signature/rpath correct) and reports capabilities. Prints JSON, exits 0/1.
if CommandLine.arguments.contains("--self-test") {
    var report: [String: Any] = [:]
    var ok = true
    for (tool, args) in [("ffmpeg", ["-hide_banner", "-version"]), ("ffprobe", ["-hide_banner", "-version"]), ("bsdtar", ["--version"])] {
        guard let url = ToolLocator.url(for: tool) else { report[tool] = "missing"; ok = false; continue }
        let p = Process()
        p.executableURL = url
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        do {
            try p.run()
            p.waitUntilExit()
            let first = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self).split(separator: "\n").first.map(String.init) ?? ""
            report[tool] = p.terminationStatus == 0 ? first : "exit \(p.terminationStatus): \(first)"
            if p.terminationStatus != 0 { ok = false }
        } catch {
            report[tool] = "failed: \(error)"; ok = false
        }
    }
    for res in ["icons/compress", "logo-menubar", "THIRD_PARTY_NOTICES"] {
        let parts = res.split(separator: "/")
        let name = String(parts.last!), sub = parts.count > 1 ? String(parts[0]) : nil
        let found = Bundle.main.url(forResource: name, withExtension: name == "THIRD_PARTY_NOTICES" ? "md" : "png", subdirectory: sub) != nil
        report["resource:\(res)"] = found
        if !found { ok = false }
    }
    let reg = CapabilityRegistry(unavailableTargets: ImageEngine.unavailableTargets)
    var paths = 0
    for input in CapabilityMatrix.inputOrder {
        paths += reg.targets(for: .conversions, items: [DraggedItem(url: URL(fileURLWithPath: "/x/a.\(Formats.fileExtension(for: input))"), isDirectory: false)]).count
    }
    report["m1ConversionPathsAvailable"] = paths
    report["unavailableTargets"] = Array(ImageEngine.unavailableTargets).sorted()
    report["version"] = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    report["ok"] = ok
    let data = try! JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
    print(String(decoding: data, as: UTF8.self))
    exit(ok ? 0 : 1)
}

if let i = CommandLine.arguments.firstIndex(of: "--render-snapshots"), i + 1 < CommandLine.arguments.count {
    _ = NSApplication.shared
    NSApp.setActivationPolicy(.prohibited)
    do { try Snapshots.render(to: URL(fileURLWithPath: CommandLine.arguments[i + 1])); exit(0) }
    catch { print("snapshot error: \(error)"); exit(1) }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
