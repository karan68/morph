import AppKit
import SwiftUI
import Jobs
import A11y
import DragKit

/// View model for one HUD.
final class HUDModel: ObservableObject {
    let job: Job
    @Published var state: JobState
    @Published var progress: Double = 0
    @Published var current: String?
    var retry: (() -> Void)?
    var dismiss: (() -> Void)?
    init(job: Job) { self.job = job; self.state = job.state }
}

/// Spec mockup 07: one small window per job, stacked top-right. Running → cancel (×); done → "Show in Finder",
/// auto-hides after 4 s; failure → plain-language message, Details, Try again (stays until closed).
final class HUDController {
    private var panels: [UUID: (NSPanel, HUDModel)] = [:]
    private var order: [UUID] = []
    var retryProvider: ((Job) -> (() -> Void)?)?

    func update(_ job: Job) {
        let model: HUDModel
        if let (_, m) = panels[job.id] { model = m } else {
            if case .cancelled = job.state { return }
            model = HUDModel(job: job)
            model.retry = retryProvider?(job)
            let panel = makePanel(model)
            panels[job.id] = (panel, model)
            order.insert(job.id, at: 0)
            model.dismiss = { [weak self] in self?.remove(job.id) }
            layout()
            panel.orderFrontRegardless()
            Announcer.say("\(job.title): \(job.subject)…", priority: .medium)
        }
        let previous = model.state
        model.state = job.state
        model.progress = job.progress
        model.current = job.currentItem
        guard previous != job.state else { return }
        switch job.state {
        case .succeeded(let urls):
            Announcer.say("Saved \(urls.map(\.lastPathComponent).joined(separator: ", ")) beside the original.")
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in self?.remove(job.id) }
        case .failed(let message, _):
            Announcer.say(message)
        case .cancelled:
            Announcer.say("\(job.title) cancelled. Nothing was saved.")
            remove(job.id)
        default: break
        }
    }

    private func makePanel(_ model: HUDModel) -> NSPanel {
        let host = NSHostingView(rootView: HUDView(model: model).environment(\.colorScheme, .light))
        let size = NSSize(width: 330 + 12, height: host.fittingSize.height)
        let p = NSPanel(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.isOpaque = false; p.backgroundColor = .clear; p.hasShadow = false
        p.level = .floating
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.isReleasedWhenClosed = false
        p.becomesKeyOnlyIfNeeded = true
        p.appearance = NSAppearance(named: .aqua)
        p.contentView = host
        return p
    }

    private func remove(_ id: UUID) {
        guard let (p, _) = panels[id] else { return }
        panels[id] = nil
        order.removeAll { $0 == id }
        let reduce = DisplayOptions.shared.reduceMotion
        NSAnimationContext.runAnimationGroup({ $0.duration = reduce ? 0.1 : 0.18; p.animator().alphaValue = 0 }, completionHandler: { p.orderOut(nil) })
        layout()
    }

    private func layout() {
        guard let f = NSScreen.main?.visibleFrame else { return }
        var top = f.maxY - 8
        for id in order {
            guard let (p, _) = panels[id] else { continue }
            if let host = p.contentView { p.setContentSize(NSSize(width: 342, height: host.fittingSize.height)) }
            let h = p.frame.height
            p.setFrameOrigin(NSPoint(x: f.maxX - p.frame.width - 10, y: top - h))
            top -= h + 2
        }
    }
}

struct HUDView: View {
    @ObservedObject var model: HUDModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                badge
                Text(title).font(.system(size: 13, weight: .semibold)).lineLimit(1).truncationMode(.middle)
                Spacer(minLength: 4)
                Button { close() } label: {
                    Image(nsImage: Icons.image("x", size: 12) ?? NSImage()).renderingMode(.template).foregroundColor(Color(Theme.ink2))
                        .frame(width: 22, height: 22).background(Circle().fill(Color(Theme.ink).opacity(0.07)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isRunning ? "Cancel \(model.job.title)" : "Dismiss")
            }
            switch model.state {
            case .queued, .running:
                HStack {
                    Text(subtitle).lineLimit(1).truncationMode(.middle)
                    Spacer()
                    Text("\(Int(model.progress * 100))%").monospacedDigit()
                }
                .font(.system(size: 12)).foregroundColor(Color(Theme.ink2)).padding(.top, 4)
                ProgressView(value: model.progress).progressViewStyle(.linear).tint(Color(Theme.accent)).padding(.top, 8)
                    .accessibilityLabel("\(model.job.title) progress")
            case .succeeded(let urls):
                HStack {
                    Text(urls.count > 1 ? "Beside the originals" : "Beside the original · \(formatBytes(urls.first))")
                    Spacer()
                    Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting(urls) }
                        .buttonStyle(.plain).foregroundColor(Color(Theme.accentInk)).font(.system(size: 12, weight: .medium))
                }
                .font(.system(size: 12)).foregroundColor(Color(Theme.ink2)).padding(.top, 4)
            case .failed(let message, let details):
                Text(message).font(.system(size: 12)).foregroundColor(Color(Theme.ink2)).padding(.top, 4).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Button("Details") { showDetails(message, details) }.buttonStyle(SmallButton())
                    if model.retry != nil { Button("Try again") { model.retry?(); close() }.buttonStyle(SmallButton()) }
                }
                .padding(.top, 8)
            case .cancelled:
                EmptyView()
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .frame(width: 330, alignment: .leading)
        .background(VisualEffect().clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.7)))
        .shadow(color: Color(Theme.rgb(0x1A124A, 0.22)), radius: 12, y: 6)
        .padding(6)
        .foregroundColor(Color(Theme.ink))
        .accessibilityElement(children: .contain)
    }

    var isRunning: Bool { if case .running = model.state { return true }; if case .queued = model.state { return true }; return false }

    var title: String {
        switch model.state {
        case .succeeded(let urls): return urls.count > 1 ? "Saved \(urls.count) files" : "Saved \(urls.first?.lastPathComponent ?? "")"
        case .failed: return model.job.itemCount > 1 ? "\(model.job.title) didn't finish" : "Couldn't finish \(model.job.subject)"
        default: return model.job.title
        }
    }

    var subtitle: String {
        if model.job.itemCount > 1, let cur = model.current {
            let idx = min(model.job.itemCount, Int(model.progress * Double(model.job.itemCount)) + 1)
            return "\(idx) of \(model.job.itemCount) · \(cur)"
        }
        return model.job.subject
    }

    @ViewBuilder var badge: some View {
        let (icon, color): (String, NSColor) = {
            switch model.state {
            case .succeeded: return ("check", Theme.teal)
            case .failed: return ("alert", Theme.danger)
            default: return ("chevron", Theme.accent)
            }
        }()
        Image(nsImage: Icons.image(icon, size: 13) ?? NSImage()).renderingMode(.template).foregroundColor(.white)
            .frame(width: 22, height: 22).background(Circle().fill(Color(color)))
            .accessibilityHidden(true)
    }

    func close() {
        if isRunning { model.job.cancel() } else { model.dismiss?() }
    }

    func formatBytes(_ url: URL?) -> String {
        guard let u = url else { return "" }
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: u.path, isDirectory: &isDir)
        if isDir.boolValue { return "folder" }
        let n = (try? u.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return ByteCountFormatter.string(fromByteCount: Int64(n), countStyle: .file)
    }

    func showDetails(_ message: String, _ details: String) {
        let a = NSAlert()
        a.messageText = message
        a.informativeText = details.isEmpty ? "No further details." : String(details.suffix(4000))
        a.alertStyle = .warning
        a.addButton(withTitle: "OK")
        a.addButton(withTitle: "Copy Details")
        NSApp.activate(ignoringOtherApps: true)
        if a.runModal() == .alertSecondButtonReturn {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString("\(message)\n\n\(details)", forType: .string)
        }
    }
}

struct SmallButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 12, weight: .medium)).padding(.horizontal, 10).frame(height: 24)
            .background(RoundedRectangle(cornerRadius: 7).fill(Color(Theme.ink).opacity(configuration.isPressed ? 0.14 : 0.07)))
    }
}
