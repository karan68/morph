#if canImport(AppKit)
import AppKit
import SwiftUI
import QuickLookThumbnailing
import Capabilities
import A11y

/// Modifier keys a wheel can be bound to (spec mockup 12; Fn and Caps Lock excluded).
public enum ModifierKey: String, CaseIterable, Codable {
    case shift, command, control, option
    public var flag: NSEvent.ModifierFlags {
        switch self { case .shift: return .shift; case .command: return .command; case .control: return .control; case .option: return .option }
    }
    public var glyph: String {
        switch self { case .shift: return "⇧"; case .command: return "⌘"; case .control: return "⌃"; case .option: return "⌥" }
    }
    public var name: String { rawValue.capitalized }
}

public struct DragSettings {
    public var keys: [WheelMode: ModifierKey] = [.conversions: .shift, .tools: .command, .actions: .control]
    public var holdToOpen = false
    public var tickSound = true
    public var haptics = true
    public var showHint = true
    public init() {}
    public var glyphs: [WheelMode: String] { keys.mapValues(\.glyph) }
}

public protocol DragControllerDelegate: AnyObject {
    var registry: CapabilityRegistry { get }
    var dragSettings: DragSettings { get }
    var isPaused: Bool { get }
    func dragControllerDidStartDrag(_ c: DragController)
    func dragControllerDidOpenWheel(_ c: DragController, mode: WheelMode)
    /// The user chose a petal. `anchor` is the wheel centre in screen coordinates (tool windows open there).
    func dragController(_ c: DragController, didChoose mode: WheelMode, target: String, items: [URL], anchor: NSPoint)
}

/// Orchestrates one drag/keyboard session: detect drag → key hint → wheel → choose (spec §5.1 state machine).
public final class DragController: NSObject, WheelViewDelegate {
    public weak var delegate: DragControllerDelegate?

    private var monitors: [Any] = []
    private var baseline = NSPasteboard(name: .drag).changeCount
    private var poll: Timer?

    private struct Session {
        var items: [DraggedItem]
        var keyboard: Bool
        var mode: WheelMode?
        var anchor: NSPoint?
        var lastFlags: NSEvent.ModifierFlags = []
        var thumbnail: NSImage?
        var waitingForDrop = false
    }
    private var session: Session?
    private var panel: WheelPanel?
    private var wheel: WheelView?
    private var hint: NSPanel?

    public override init() { super.init() }

    public var isActive: Bool { session != nil }

    // MARK: Monitoring

    public func start() {
        stop()
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .leftMouseDragged]
        if let g = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] e in self?.handle(e) }) { monitors.append(g) }
    }

    public func stop() {
        monitors.forEach { NSEvent.removeMonitor($0) }
        monitors = []
    }

    private func handle(_ e: NSEvent) {
        switch e.type {
        case .leftMouseDown:
            if session == nil { baseline = NSPasteboard(name: .drag).changeCount }
        case .leftMouseDragged:
            guard session == nil, delegate?.isPaused == false else { return }
            let pb = NSPasteboard(name: .drag)
            guard pb.changeCount != baseline else { return }
            baseline = pb.changeCount
            let urls = (pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? []
            guard !urls.isEmpty else { return }
            beginDrag(urls: urls)
        default: break
        }
    }

    /// Starts a drag session. Also used by the onboarding window, whose drag source is Morph itself
    /// (global monitors don't see Morph's own events).
    public func beginDrag(urls: [URL]) {
        end()
        session = Session(items: urls.map { DraggedItem(url: $0, isDirectory: (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true) },
                          keyboard: false, mode: nil, anchor: nil, lastFlags: NSEvent.modifierFlags.intersection(Self.relevant))
        loadThumbnail()
        delegate?.dragControllerDidStartDrag(self)
        if delegate?.dragSettings.showHint == true { showHint() }
        let t = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        poll = t
    }

    static let relevant: NSEvent.ModifierFlags = [.shift, .command, .control, .option]

    private func tick() {
        guard var s = session, !s.keyboard else { return }
        // Mouse released → the drag is over (drop elsewhere, Esc in the source app, or drop on our panel).
        if NSEvent.pressedMouseButtons & 1 == 0 {
            if let p = panel, p.isVisible, p.frame.contains(NSEvent.mouseLocation), !s.waitingForDrop {
                // Give performDragOperation a moment to arrive before tearing down.
                s.waitingForDrop = true
                session = s
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                    if self?.session?.waitingForDrop == true { self?.end() }
                }
            } else if !s.waitingForDrop {
                end()
            }
            return
        }
        positionHint()
        let flags = NSEvent.modifierFlags.intersection(Self.relevant)
        let newly = flags.subtracting(s.lastFlags)
        let released = s.lastFlags.subtracting(flags)
        s.lastFlags = flags
        session = s
        let keys = delegate?.dragSettings.keys ?? DragSettings().keys
        if flags.rawValue.nonzeroBitCount == 1, newly == flags,
           let mode = keys.first(where: { $0.value.flag == flags })?.key {
            open(mode)
        } else if delegate?.dragSettings.holdToOpen == true, let m = s.mode, let k = keys[m], released.contains(k.flag) {
            closeWheelKeepSession()
        }
    }

    // MARK: Keyboard path (spec §6 A3/A4)

    /// Opens the conversion wheel (or actions, if there are no conversions) for files without a drag.
    public func openKeyboard(urls: [URL], at point: NSPoint? = nil) {
        end()
        guard !urls.isEmpty else { return }
        let items = urls.map { DraggedItem(url: $0, isDirectory: (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true) }
        session = Session(items: items, keyboard: true, mode: nil, anchor: nil)
        loadThumbnail()
        let reg = delegate?.registry ?? CapabilityRegistry()
        open(reg.targets(for: .conversions, items: items).isEmpty ? .actions : .conversions, at: point ?? NSEvent.mouseLocation)
    }

    // MARK: Wheel

    private func open(_ mode: WheelMode, at point: NSPoint? = nil) {
        guard var s = session else { return }
        hideHint()
        let reg = delegate?.registry ?? CapabilityRegistry()
        let settings = delegate?.dragSettings ?? DragSettings()
        let targets = reg.targets(for: mode, items: s.items)
        let content = WheelContent(mode: mode, targets: targets,
                                   emptyText: reg.emptyText(for: mode, items: s.items, keys: settings.glyphs),
                                   thumbnail: s.thumbnail, chipText: chipText(s.items), keyGlyphs: settings.glyphs)
        let switching = s.mode != nil && wheel != nil
        s.mode = mode
        if let w = wheel, switching {
            w.setContent(content, animated: true)
        } else {
            let anchor = clamp(point ?? NSEvent.mouseLocation)
            s.anchor = anchor
            showPanel(content: content, anchor: anchor, keyboard: s.keyboard)
        }
        session = s
        if settings.haptics { NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now) }
        let what = mode == .actions ? "file action" : mode == .tools ? "file tool" : "conversion"
        Announcer.say(targets.isEmpty ? content.emptyText.replacingOccurrences(of: "\n", with: " ")
                      : "\(targets.count) \(what)\(targets.count == 1 ? "" : "s"). " + (s.keyboard ? "Use the arrow keys, then Return." : "Drop on one."))
        delegate?.dragControllerDidOpenWheel(self, mode: mode)
    }

    private func clamp(_ p: NSPoint) -> NSPoint {
        let screen = NSScreen.screens.first { $0.frame.contains(p) } ?? NSScreen.main
        guard let f = screen?.visibleFrame else { return p }
        let m = CGFloat(WheelGeometry.backdrop) + 14
        let legend = WheelView.legendHeight + 10
        return NSPoint(x: max(f.minX + m, min(f.maxX - m, p.x)), y: max(f.minY + m + legend, min(f.maxY - m, p.y)))
    }

    private func showPanel(content: WheelContent, anchor: NSPoint, keyboard: Bool) {
        let view = WheelView(content: content)
        view.delegate = self
        view.keyboardMode = keyboard
        let keys = delegate?.dragSettings.keys ?? DragSettings().keys
        view.modifierModes = Dictionary(uniqueKeysWithValues: keys.map { ($0.value.flag.rawValue, $0.key) })
        let size = WheelView.size
        let origin = NSPoint(x: anchor.x - view.center.x, y: anchor.y - (size.height - view.center.y))
        let p = WheelPanel(contentRect: NSRect(origin: origin, size: size), keyboard: keyboard)
        p.install(view)
        panel = p; wheel = view
        let reduce = DisplayOptions.shared.reduceMotion
        p.alphaValue = 0
        if keyboard { NSApp.activate(ignoringOtherApps: true); p.makeKeyAndOrderFront(nil); p.makeFirstResponder(view) } else { p.orderFrontRegardless() }
        if !reduce, let layer = view.layer {
            let a = CABasicAnimation(keyPath: "transform.scale")
            a.fromValue = 0.9; a.toValue = 1; a.duration = 0.14; a.timingFunction = CAMediaTimingFunction(name: .easeOut)
            layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            layer.position = CGPoint(x: view.frame.midX, y: view.frame.midY)
            layer.add(a, forKey: "pop")
        }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = reduce ? 0.1 : 0.14
            p.animator().alphaValue = 1
        }
        if keyboard, !content.targets.isEmpty { view.setHighlight(0) }
        NSAccessibility.post(element: view, notification: .created)
    }

    private func closeWheelKeepSession() {
        guard var s = session else { return }
        s.mode = nil; s.anchor = nil
        session = s
        let p = panel
        panel = nil; wheel = nil
        p?.orderOut(nil)
    }

    /// Ends the session and hides everything (no file is written).
    public func end() {
        poll?.invalidate(); poll = nil
        hideHint()
        if let p = panel {
            let reduce = DisplayOptions.shared.reduceMotion
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = reduce ? 0.1 : 0.15
                p.animator().alphaValue = 0
            }, completionHandler: { p.orderOut(nil) })
        }
        panel = nil; wheel = nil
        session = nil
        baseline = NSPasteboard(name: .drag).changeCount
    }

    // MARK: WheelViewDelegate

    public func wheelView(_ view: WheelView, didHighlight index: Int?) {
        guard index != nil, let settings = delegate?.dragSettings else { return }
        if settings.tickSound { (NSSound(named: "Tink")?.copy() as? NSSound).map { $0.volume = 0.35; $0.play() } }
        if settings.haptics { NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now) }
        if let i = index, i < view.content.targets.count {
            let name = view.content.accessibleName(i)
            Announcer.say("\(name), \(i + 1) of \(view.content.targets.count)", priority: .medium)
        }
    }

    public func wheelView(_ view: WheelView, didChoose index: Int, droppedURLs: [URL]?) {
        guard let s = session, let mode = s.mode, index < view.content.targets.count else { return }
        let target = view.content.targets[index]
        var items = s.items.map(\.url)
        if let dropped = droppedURLs, !dropped.isEmpty { items = dropped }
        let anchor = s.anchor ?? NSEvent.mouseLocation
        view.flashAndFinish(index) { [weak self] in
            guard let self = self else { return }
            self.end()
            self.delegate?.dragController(self, didChoose: mode, target: target, items: items, anchor: anchor)
        }
    }

    public func wheelViewDidCancel(_ view: WheelView) {
        end()
        Announcer.say("Cancelled.")
    }

    public func wheelView(_ view: WheelView, didTapModifierFor mode: WheelMode) { open(mode) }

    public func wheelViewDragExited(_ view: WheelView) {}

    // MARK: Hint + thumbnail

    private func chipText(_ items: [DraggedItem]) -> String? {
        if items.count > 1 { return "\(items.count) files" }
        guard let i = items.first else { return nil }
        if i.isDirectory { return "Folder" }
        let size = (try? i.url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }

    private func loadThumbnail() {
        guard let first = session?.items.first else { return }
        session?.thumbnail = NSWorkspace.shared.icon(forFile: first.url.path)
        let req = QLThumbnailGenerator.Request(fileAt: first.url, size: CGSize(width: 92, height: 92), scale: 2, representationTypes: .thumbnail)
        QLThumbnailGenerator.shared.generateBestRepresentation(for: req) { [weak self] rep, _ in
            guard let rep = rep else { return }
            DispatchQueue.main.async {
                guard let self = self, self.session?.items.first?.url == first.url else { return }
                self.session?.thumbnail = rep.nsImage
                if let w = self.wheel, w.highlighted == nil {
                    var c = w.content; c.thumbnail = rep.nsImage
                    w.setContent(c, animated: false)
                }
            }
        }
    }

    private func showHint() {
        let glyphs = delegate?.dragSettings.glyphs ?? DragSettings().glyphs
        let host = NSHostingView(rootView: KeyHintView(glyphs: glyphs))
        host.frame.size = host.fittingSize
        let p = NSPanel(contentRect: NSRect(origin: .zero, size: host.fittingSize), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.isOpaque = false; p.backgroundColor = .clear; p.hasShadow = true; p.level = .popUpMenu
        p.ignoresMouseEvents = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        p.contentView = host
        hint = p
        positionHint()
        p.orderFrontRegardless()
    }

    private func positionHint() {
        guard let h = hint else { return }
        let m = NSEvent.mouseLocation
        h.setFrameOrigin(NSPoint(x: m.x + 24, y: m.y + 60))
    }

    private func hideHint() { hint?.orderOut(nil); hint = nil }
}

/// Spec mockup 02: "⇧ Convert ⌘ Tools ⌃ Actions — Tap a key while dragging. The wheel stays open."
struct KeyHintView: View {
    let glyphs: [WheelMode: String]
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                key(glyphs[.conversions] ?? "⇧"); Text("Convert")
                key(glyphs[.tools] ?? "⌘"); Text("Tools")
                key(glyphs[.actions] ?? "⌃"); Text("Actions")
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(Color(Theme.ink))
            Text("Tap a key while dragging. The wheel stays open.")
                .font(.system(size: 12)).foregroundColor(Color(Theme.ink2))
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(VisualEffect().clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.7)))
        .padding(6)
        .accessibilityElement(children: .combine)
    }
    func key(_ g: String) -> some View {
        Text(g).font(.system(size: 12, weight: .semibold)).frame(minWidth: 26, minHeight: 24)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white).shadow(color: .black.opacity(0.25), radius: 0, y: 1))
    }
}

/// Light glass background used by Morph's floating surfaces.
public struct VisualEffect: NSViewRepresentable {
    public init() {}
    public func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .popover; v.blendingMode = .behindWindow; v.state = .active
        v.appearance = NSAppearance(named: .aqua)
        return v
    }
    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

/// Borderless, non-activating floating panel hosting the wheel (spec §7.1).
final class WheelPanel: NSPanel {
    private let keyboard: Bool
    init(contentRect: NSRect, keyboard: Bool) {
        self.keyboard = keyboard
        super.init(contentRect: contentRect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        isReleasedWhenClosed = false
        appearance = NSAppearance(named: .aqua)
    }
    override var canBecomeKey: Bool { keyboard }
    override var canBecomeMain: Bool { false }

    func install(_ wheel: WheelView) {
        let root = NSView(frame: NSRect(origin: .zero, size: frame.size))
        root.wantsLayer = true
        // Blur behind the ring only (masked to the backdrop circle). Reduce Transparency is honoured by
        // NSVisualEffectView itself and by WheelView's solid high-contrast style.
        let B = CGFloat(WheelGeometry.backdrop)
        let c = wheel.center
        let blur = NSVisualEffectView(frame: NSRect(x: c.x - B, y: frame.height - c.y - B, width: 2 * B, height: 2 * B))
        blur.material = .popover; blur.blendingMode = .behindWindow; blur.state = .active
        blur.maskImage = NSImage(size: blur.frame.size, flipped: false) { r in NSBezierPath(ovalIn: r).fill(); return true }
        root.addSubview(blur)
        wheel.frame = root.bounds
        root.addSubview(wheel)
        contentView = root
    }
}
#endif
