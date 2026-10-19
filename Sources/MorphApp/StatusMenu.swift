import AppKit
import QuickLookThumbnailing
import A11y

/// Spec mockup 01: menu-bar app, no Dock icon. Native NSMenu for keyboard + VoiceOver support.
final class StatusMenu: NSObject, NSMenuDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let settings = SettingsStore.shared
    var openWheelForSelection: (() -> Void)?
    var openSettings: (() -> Void)?
    var openHelp: (() -> Void)?
    private var thumbs: [String: NSImage] = [:]

    override init() {
        super.init()
        if let b = item.button {
            b.image = Self.logo(size: 18)
            b.setAccessibilityLabel("Morph")
            b.toolTip = "Morph — drag a file, then tap ⇧ ⌘ or ⌃"
        }
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
    }

    static func logo(size: CGFloat) -> NSImage? {
        guard let url = Bundle.main.url(forResource: "logo-menubar", withExtension: "png"), let img = NSImage(contentsOf: url) else { return nil }
        img.size = NSSize(width: size, height: size)
        return img
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.addItem(header())
        menu.addItem(.separator())
        let recentHeader = NSMenuItem(title: "Recent", action: nil, keyEquivalent: "")
        recentHeader.isEnabled = false
        menu.addItem(recentHeader)
        let recent = settings.recent.filter { FileManager.default.fileExists(atPath: $0.path) }.prefix(3)
        if recent.isEmpty {
            let none = NSMenuItem(title: "Converted files appear here", action: nil, keyEquivalent: "")
            none.isEnabled = false
            menu.addItem(none)
        }
        for r in recent { menu.addItem(recentItem(r)) }
        menu.addItem(.separator())
        let wheel = NSMenuItem(title: "Open wheel for Finder selection", action: #selector(openWheel), keyEquivalent: "")
        wheel.target = self
        wheel.toolTip = settings.hotKeyDescription
        wheel.attributedTitle = titleWithShortcut("Open wheel for Finder selection", settings.hotKeyDescription)
        wheel.image = Icons.image("keyboard", size: 15)
        menu.addItem(wheel)
        let shelf = NSMenuItem(title: FloatShelf.shared.isVisible ? "Hide Float shelf" : "Show Float shelf", action: #selector(toggleShelf), keyEquivalent: "")
        shelf.target = self
        shelf.image = Icons.image("float", size: 15)
        shelf.isEnabled = !FloatShelf.shared.items.isEmpty
        menu.addItem(shelf)
        let pause = NSMenuItem(title: settings.paused ? "Resume Morph" : "Pause Morph", action: #selector(togglePause), keyEquivalent: "")
        pause.target = self
        pause.image = Icons.image(settings.paused ? "play" : "pause", size: 15)
        menu.addItem(pause)
        menu.addItem(.separator())
        let s = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        s.target = self; s.image = Icons.image("settings", size: 15)
        menu.addItem(s)
        let help = NSMenuItem(title: "Keyboard & accessibility help", action: #selector(showHelp), keyEquivalent: "")
        help.target = self; help.image = Icons.image("accessibility", size: 15)
        menu.addItem(help)
        let quit = NSMenuItem(title: "Quit Morph", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
        menu.addItem(.separator())
        menu.addItem(footer())
    }

    private func header() -> NSMenuItem {
        let i = NSMenuItem()
        let v = NSView(frame: NSRect(x: 0, y: 0, width: 318, height: 58))
        let logo = NSImageView(frame: NSRect(x: 14, y: 30, width: 20, height: 20))
        logo.image = Self.logo(size: 20)
        let name = NSTextField(labelWithString: "Morph")
        name.font = .systemFont(ofSize: 13, weight: .bold)
        name.frame = NSRect(x: 40, y: 31, width: 120, height: 18)
        let ready = !settings.paused
        let pill = NSTextField(labelWithString: ready ? "Ready" : "Paused")
        pill.font = .systemFont(ofSize: 12, weight: .semibold)
        pill.textColor = ready ? Theme.teal : Theme.ink2
        pill.wantsLayer = true
        pill.layer?.backgroundColor = (ready ? Theme.tealSoft : Theme.rgb(0x1C1B22, 0.07)).cgColor
        pill.layer?.cornerRadius = 9
        pill.alignment = .center
        pill.frame = NSRect(x: 318 - 14 - 62, y: 30, width: 62, height: 20)
        let k = SettingsStore.shared
        let sub = NSTextField(labelWithString: "Drag any file, then tap \(k.convertKey.glyph) \(k.toolsKey.glyph) or \(k.actionsKey.glyph)")
        sub.font = .systemFont(ofSize: 12)
        sub.textColor = Theme.ink2
        sub.frame = NSRect(x: 14, y: 6, width: 290, height: 18)
        [logo, name, pill, sub].forEach(v.addSubview)
        v.setAccessibilityElement(true)
        v.setAccessibilityLabel("Morph, \(ready ? "ready" : "paused"). Drag any file, then tap \(k.convertKey.name), \(k.toolsKey.name) or \(k.actionsKey.name).")
        i.view = v
        return i
    }

    private func footer() -> NSMenuItem {
        let i = NSMenuItem()
        let v = NSView(frame: NSRect(x: 0, y: 0, width: 318, height: 28))
        let icon = NSImageView(frame: NSRect(x: 14, y: 6, width: 15, height: 15))
        icon.image = Icons.tinted("shield", size: 15, color: Theme.teal)
        let t = NSTextField(labelWithString: "Runs on this Mac. Files are never uploaded.")
        t.font = .systemFont(ofSize: 12, weight: .semibold)
        t.textColor = Theme.teal
        t.frame = NSRect(x: 34, y: 5, width: 280, height: 18)
        [icon, t].forEach(v.addSubview)
        v.setAccessibilityElement(true)
        v.setAccessibilityLabel("Runs on this Mac. Files are never uploaded.")
        i.view = v
        return i
    }

    private func recentItem(_ r: RecentItem) -> NSMenuItem {
        let url = URL(fileURLWithPath: r.path)
        let i = NSMenuItem(title: url.lastPathComponent, action: #selector(reveal(_:)), keyEquivalent: "")
        i.target = self
        i.representedObject = url
        let rel = RelativeDateTimeFormatter().localizedString(for: r.date, relativeTo: Date())
        let t = NSMutableAttributedString(string: url.lastPathComponent, attributes: [.font: NSFont.menuFont(ofSize: 13)])
        t.append(NSAttributedString(string: "\n\(r.detail) · \(rel)", attributes: [.font: NSFont.systemFont(ofSize: 11.5), .foregroundColor: NSColor.secondaryLabelColor]))
        i.attributedTitle = t
        i.setAccessibilityLabel("\(url.lastPathComponent), \(r.detail), \(rel). Show in Finder.")
        let thumb = thumbs[r.path] ?? NSWorkspace.shared.icon(forFile: r.path)
        thumb.size = NSSize(width: 30, height: 30)
        i.image = thumb
        if thumbs[r.path] == nil {
            let req = QLThumbnailGenerator.Request(fileAt: url, size: CGSize(width: 30, height: 30), scale: 2, representationTypes: .thumbnail)
            QLThumbnailGenerator.shared.generateBestRepresentation(for: req) { [weak self] rep, _ in
                guard let img = rep?.nsImage else { return }
                DispatchQueue.main.async { self?.thumbs[r.path] = img }
            }
        }
        return i
    }

    private func titleWithShortcut(_ title: String, _ shortcut: String) -> NSAttributedString {
        let s = NSMutableAttributedString(string: title, attributes: [.font: NSFont.menuFont(ofSize: 13)])
        s.append(NSAttributedString(string: "   \(shortcut)", attributes: [.font: NSFont.menuFont(ofSize: 13), .foregroundColor: NSColor.secondaryLabelColor]))
        return s
    }

    @objc private func reveal(_ sender: NSMenuItem) {
        if let u = sender.representedObject as? URL { NSWorkspace.shared.activateFileViewerSelecting([u]) }
    }
    @objc private func openWheel() { openWheelForSelection?() }
    @objc private func toggleShelf() { FloatShelf.shared.toggle() }
    @objc private func togglePause() {
        settings.paused.toggle()
        Announcer.say(settings.paused ? "Morph paused." : "Morph resumed.")
    }
    @objc private func showSettings() { openSettings?() }
    @objc private func showHelp() { openHelp?() }
}
