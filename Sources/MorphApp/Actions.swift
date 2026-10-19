import AppKit
import SwiftUI
import A11y
import DragKit

/// The six file actions (spec §3.6). They work on files, folders and mixed selections.
enum Actions {
    static func run(_ id: String, urls: [URL]) {
        switch id {
        case "airDrop":
            guard let s = NSSharingService(named: .sendViaAirDrop), s.canPerform(withItems: urls) else {
                alert("AirDrop isn't available", "Turn on Wi-Fi and Bluetooth, then try again.")
                return
            }
            NSApp.activate(ignoringOtherApps: true)
            s.perform(withItems: urls)
        case "float":
            FloatShelf.shared.add(urls)
            Announcer.say("Added \(urls.count) item\(urls.count == 1 ? "" : "s") to the Float shelf.")
        case "copy":
            NSPasteboard.general.clearContents()
            NSPasteboard.general.writeObjects(urls as [NSURL])
            Announcer.say("Copied \(urls.count) item\(urls.count == 1 ? "" : "s"). Paste in Finder with Command V.")
        case "move":
            move(urls)
        case "copyPath":
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(urls.map(\.path).joined(separator: "\n"), forType: .string)
            Announcer.say("Copied \(urls.count) path\(urls.count == 1 ? "" : "s").")
        case "openTerminal":
            openTerminal(urls)
        default: break
        }
    }

    static func move(_ urls: [URL]) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Move Here"
        panel.message = "Choose where to move \(urls.count == 1 ? "“\(urls[0].lastPathComponent)”" : "\(urls.count) items")."
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let dest = panel.url else { return }
        var moved: [URL] = [], failed: [String] = []
        for u in urls {
            guard u.deletingLastPathComponent().standardizedFileURL != dest.standardizedFileURL else { continue }
            var target = dest.appendingPathComponent(u.lastPathComponent)
            var n = 2
            let base = u.deletingPathExtension().lastPathComponent, ext = u.pathExtension
            while FileManager.default.fileExists(atPath: target.path) {
                target = dest.appendingPathComponent(ext.isEmpty ? "\(base) \(n)" : "\(base) \(n).\(ext)"); n += 1
            }
            do { try FileManager.default.moveItem(at: u, to: target); moved.append(target) } catch { failed.append(u.lastPathComponent) }
        }
        if !moved.isEmpty { NSWorkspace.shared.activateFileViewerSelecting(moved) }
        if !failed.isEmpty { alert("Couldn't move \(failed.joined(separator: ", "))", "You may not have permission to move these items.") }
        Announcer.say("Moved \(moved.count) item\(moved.count == 1 ? "" : "s") to \(dest.lastPathComponent).")
    }

    static func openTerminal(_ urls: [URL]) {
        guard let u = urls.first else { return }
        let isDir = (try? u.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        let folder = isDir ? u : u.deletingLastPathComponent()
        let ws = NSWorkspace.shared
        // iTerm2 if installed, otherwise Terminal (spec prototype copy: "Terminal (or iTerm2 if installed)").
        guard let app = ws.urlForApplication(withBundleIdentifier: "com.googlecode.iterm2")
                ?? ws.urlForApplication(withBundleIdentifier: "com.apple.Terminal") else { return }
        ws.open([folder], withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration())
    }

    static func alert(_ title: String, _ text: String) {
        let a = NSAlert(); a.messageText = title; a.informativeText = text
        NSApp.activate(ignoringOtherApps: true)
        a.runModal()
    }
}

/// Spec mockup 11: a shelf pinned to the right screen edge. Holds file references (not copies);
/// items show "missing" if the file moves. Drag items out into any app.
final class FloatShelf: ObservableObject {
    static let shared = FloatShelf()
    @Published var items: [URL] = []
    @Published var missing: Set<URL> = []
    private var panel: NSPanel?
    private var timer: Timer?

    var isVisible: Bool { panel?.isVisible == true }

    func add(_ urls: [URL]) {
        for u in urls where !items.contains(u) { items.append(u) }
        show()
    }

    func toggle() { isVisible ? hide() : show() }

    func show() {
        if panel == nil {
            let host = NSHostingView(rootView: FloatShelfView(shelf: self).environment(\.colorScheme, .light))
            let p = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 124, height: 300), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            p.isOpaque = false; p.backgroundColor = .clear; p.hasShadow = false
            p.level = .floating
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            p.isReleasedWhenClosed = false
            p.becomesKeyOnlyIfNeeded = true
            p.contentView = host
            p.setAccessibilityLabel("Float shelf")
            panel = p
        }
        layout()
        panel?.orderFrontRegardless()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.refresh() }
    }

    func hide() { panel?.orderOut(nil); timer?.invalidate() }

    func clear() { items = []; missing = []; hide(); Announcer.say("Float shelf cleared.") }

    func refresh() {
        let m = Set(items.filter { !FileManager.default.fileExists(atPath: $0.path) })
        if m != missing { missing = m }
        layout()
    }

    func layout() {
        guard let p = panel, let host = p.contentView, let f = NSScreen.main?.visibleFrame else { return }
        let size = host.fittingSize
        p.setContentSize(size)
        p.setFrameOrigin(NSPoint(x: f.maxX - size.width - 4, y: f.midY - size.height / 2))
    }
}

struct FloatShelfView: View {
    @ObservedObject var shelf: FloatShelf
    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 5) {
                Image(nsImage: Icons.image("float", size: 13) ?? NSImage()).renderingMode(.template)
                Text("Float").font(.system(size: 12, weight: .bold))
            }
            .foregroundColor(Color(Theme.ink2))
            .accessibilityAddTraits(.isHeader)
            ForEach(shelf.items, id: \.self) { u in
                let gone = shelf.missing.contains(u)
                VStack(spacing: 4) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: u.path)).resizable().frame(width: 52, height: 52)
                    Text(u.lastPathComponent).font(.system(size: 11)).lineLimit(2).multilineTextAlignment(.center).frame(width: 96)
                    if gone { Text("missing").font(.system(size: 10, weight: .semibold)).foregroundColor(Color(Theme.danger)) }
                }
                .opacity(gone ? 0.45 : 1)
                .onDrag { NSItemProvider(contentsOf: u) ?? NSItemProvider() }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(gone ? "\(u.lastPathComponent), missing" : u.lastPathComponent)
                .accessibilityHint("Drag into another app")
            }
            Button("Clear") { shelf.clear() }.buttonStyle(SmallButton())
        }
        .padding(.vertical, 10).padding(.horizontal, 8)
        .frame(width: 112)
        .background(VisualEffect().clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.7)))
        .shadow(color: Color(Theme.rgb(0x1A124A, 0.22)), radius: 12, y: 6)
        .padding(6)
        .foregroundColor(Color(Theme.ink))
    }
}
