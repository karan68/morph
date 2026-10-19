#if canImport(AppKit)
import AppKit
import SwiftUI
import Engines
import A11y

/// Opens a tool window at the drop point (spec mockup 09: "Window opens at the drop point, focused.
/// Return = primary, Esc = Cancel.") and reports the chosen options.
public enum ToolWindows {
    /// Tools that need settings before running. Others (Mute, Extract, multi-file Metadata) run immediately.
    public static func needsWindow(tool: String, itemCount: Int) -> Bool {
        switch tool {
        case "compress", "cropImage": return true
        case "trimVideo", "trimAudio", "removeMetadata": return itemCount == 1
        default: return false
        }
    }

    private static var open: [NSWindow] = []

    @MainActor
    public static func present(tool: String, items: [URL], anchor: NSPoint, onApply: @escaping (ToolOptions) -> Void) {
        var window: NSWindow!
        let close: () -> Void = {
            window?.orderOut(nil)
            open.removeAll { $0 === window }
        }
        let finish: (ToolOptions?) -> Void = { opts in
            close()
            if let o = opts { onApply(o) } else { Announcer.say("Cancelled.") }
        }
        let view: AnyView
        switch tool {
        case "compress": view = AnyView(CompressView(items: items, done: finish))
        case "removeMetadata": view = AnyView(MetadataView(item: items[0], done: finish))
        case "cropImage": view = AnyView(CropImageView(items: items, done: finish))
        case "trimVideo": view = AnyView(TrimVideoView(item: items[0], done: finish))
        case "trimAudio": view = AnyView(TrimAudioView(item: items[0], done: finish))
        default: onApply(.none); return
        }
        let host = NSHostingController(rootView: view.environment(\.colorScheme, .light))
        window = ToolWindow(contentViewController: host)
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        [.closeButton, .miniaturizeButton, .zoomButton].forEach { window.standardWindowButton($0)?.isHidden = true }
        window.isMovableByWindowBackground = true
        window.appearance = NSAppearance(named: .aqua)
        window.title = CapabilityName.tool(tool)
        window.level = .floating
        window.isReleasedWhenClosed = false
        (window as? ToolWindow)?.onEscape = { finish(nil) }
        window.layoutIfNeeded()
        let size = window.frame.size
        let screen = NSScreen.screens.first { $0.frame.contains(anchor) } ?? NSScreen.main
        var origin = NSPoint(x: anchor.x - size.width / 2, y: anchor.y - size.height / 2)
        if let f = screen?.visibleFrame {
            origin.x = max(f.minX + 8, min(f.maxX - size.width - 8, origin.x))
            origin.y = max(f.minY + 8, min(f.maxY - size.height - 8, origin.y))
        }
        window.setFrameOrigin(origin)
        open.append(window)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        Announcer.say("\(window.title) window. Return to apply, Escape to cancel.")
    }
}

final class ToolWindow: NSWindow {
    var onEscape: (() -> Void)?
    override func cancelOperation(_ sender: Any?) { onEscape?() }
    override var canBecomeKey: Bool { true }
}

enum CapabilityName {
    static func tool(_ id: String) -> String {
        ["compress": "Compress", "removeMetadata": "Metadata", "cropImage": "Crop Image", "trimVideo": "Trim Video", "trimAudio": "Trim Audio"][id] ?? id
    }
}

// MARK: Shared chrome (spec mockups 09–10)

struct ToolChrome<Content: View>: View {
    let title: String
    let primary: String
    var primaryEnabled = true
    let onReset: (() -> Void)?
    let onCancel: () -> Void
    let onPrimary: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundColor(Color(Theme.ink))
                    .accessibilityAddTraits(.isHeader)
                HStack {
                    Button(action: onCancel) {
                        Image(nsImage: Icons.image("x", size: 14) ?? NSImage()).renderingMode(.template)
                            .foregroundColor(Color(Theme.ink2))
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(Color(Theme.ink).opacity(0.07)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                    .padding(.leading, 12)
                    Spacer()
                }
            }
            .frame(height: 46)
            Divider()
            content()
                .padding(.horizontal, 20).padding(.vertical, 18)
                .frame(maxWidth: .infinity, alignment: .leading)
            Divider()
            HStack(spacing: 10) {
                if let r = onReset { Button("Reset", action: r).buttonStyle(MorphButtonStyle()) }
                Spacer()
                Button("Cancel", action: onCancel).buttonStyle(MorphButtonStyle()).keyboardShortcut(.cancelAction)
                Button(primary, action: onPrimary).buttonStyle(MorphButtonStyle(primary: true))
                    .keyboardShortcut(.defaultAction).disabled(!primaryEnabled)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
        .background(Color(Theme.rgb(0xFCFCFF, 0.96)))
        .foregroundColor(Color(Theme.ink))
        .font(.system(size: 13))
    }
}

struct MorphButtonStyle: ButtonStyle {
    var primary = false
    @Environment(\.isEnabled) var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 12).frame(height: 28)
            .foregroundColor(primary ? .white : Color(Theme.ink))
            .background(RoundedRectangle(cornerRadius: Theme.controlRadius)
                .fill(primary ? Color(Theme.accent) : Color(Theme.ink).opacity(0.07)))
            .opacity(enabled ? (configuration.isPressed ? 0.8 : 1) : 0.45)
    }
}

/// Segmented control styled like the mockups (white selected segment on a light track).
struct MorphSegmented<T: Hashable>: View {
    let label: String
    let options: [(T, String)]
    @Binding var selection: T
    var body: some View {
        HStack(spacing: 0) {
            ForEach(options.indices, id: \.self) { i in
                let (value, title) = options[i]
                let on = value == selection
                Button { selection = value } label: {
                    Text(title).font(.system(size: 13, weight: .medium))
                        .foregroundColor(on ? Color(Theme.ink) : Color(Theme.ink2))
                        .padding(.horizontal, 12).padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 6).fill(on ? Color.white : Color.clear)
                            .shadow(color: .black.opacity(on ? 0.14 : 0), radius: 1.5, y: 1))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: Theme.controlRadius).fill(Color(Theme.ink).opacity(0.07)))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }
}

struct Row<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content
    var body: some View {
        HStack(spacing: 10) {
            Text(label).foregroundColor(Color(Theme.ink2)).frame(width: 110, alignment: .leading)
            content()
        }
    }
}

struct FileHeader: View {
    let url: URL
    let subtitle: String
    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 2) {
                Text(url.lastPathComponent).font(.system(size: 13, weight: .bold)).lineLimit(1).truncationMode(.middle)
                Text(subtitle).foregroundColor(Color(Theme.ink3))
            }
        }
        .accessibilityElement(children: .combine)
    }
}

func fileSize(_ url: URL) -> Int64 {
    Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
}

func formatBytes(_ n: Int64) -> String { ByteCountFormatter.string(fromByteCount: n, countStyle: .file) }

func timecode(_ t: Double) -> String {
    let ms = Int((max(0, t) * 100).rounded())
    let m = ms / 6000, s = (ms / 100) % 60, cs = ms % 100
    return String(format: "%d:%02d.%02d", m, s, cs)
}

func parseTimecode(_ s: String) -> Double? {
    let parts = s.split(separator: ":").map { Double($0.trimmingCharacters(in: .whitespaces)) }
    guard !parts.contains(where: { $0 == nil }) else { return nil }
    let v = parts.compactMap { $0 }
    switch v.count {
    case 1: return v[0]
    case 2: return v[0] * 60 + v[1]
    case 3: return v[0] * 3600 + v[1] * 60 + v[2]
    default: return nil
    }
}
#endif

#if canImport(AppKit)
/// Factories used by `Morph --render-snapshots` (visual comparison with the spec mockups on CI).
public enum ToolWindowPreviews {
    public static func compress(_ items: [URL]) -> AnyView { AnyView(CompressView(items: items, done: { _ in })) }
    public static func crop(_ items: [URL]) -> AnyView { AnyView(CropImageView(items: items, done: { _ in })) }
}
#endif
