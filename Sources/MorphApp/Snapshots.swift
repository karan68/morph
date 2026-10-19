import AppKit
import SwiftUI
import Capabilities
import Jobs
import Engines
import DragKit
import ToolWindows
import A11y

/// `Morph --render-snapshots <dir>`: renders the real native views offscreen to PNG so CI can publish them for
/// side-by-side comparison with the spec mockups (docs/spec/mockups). No user files are touched.
enum Snapshots {
    static func render(to dir: URL) throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let glyphs: [WheelMode: String] = [.conversions: "⇧", .tools: "⌘", .actions: "⌃"]
        let reg = CapabilityRegistry(unavailableTargets: ImageEngine.unavailableTargets)
        let thumb = Bundle.main.url(forResource: "logo", withExtension: "png").flatMap(NSImage.init(contentsOf:))
        func item(_ n: String, dir: Bool = false) -> DraggedItem { DraggedItem(url: URL(fileURLWithPath: "/tmp/\(n)"), isDirectory: dir) }

        func wheel(_ name: String, mode: WheelMode, items: [DraggedItem], highlight: Int?, keyboard: Bool = false, chip: String = "4.8 MB") throws {
            let c = WheelContent(mode: mode, targets: reg.targets(for: mode, items: items),
                                 emptyText: reg.emptyText(for: mode, items: items, keys: glyphs), thumbnail: thumb, chipText: chip, keyGlyphs: glyphs)
            let v = WheelView(content: c)
            v.keyboardMode = keyboard
            if let h = highlight { v.setHighlight(h) }
            try save(v, background: true, to: dir.appendingPathComponent("\(name).png"))
        }
        try wheel("wheel-convert-heic", mode: .conversions, items: [item("kyoto-trip.heic")], highlight: 1)
        try wheel("wheel-tools-mov", mode: .tools, items: [item("harbor.mov")], highlight: 3)
        try wheel("wheel-actions-folder", mode: .actions, items: [item("Invoices 2026", dir: true)], highlight: 1, chip: "Folder")
        try wheel("wheel-idle-jpg", mode: .conversions, items: [item("photo.jpg")], highlight: nil)
        try wheel("wheel-multi-jpg", mode: .tools, items: [item("a.jpg"), item("b.jpg"), item("c.jpg")], highlight: nil, chip: "3 files")
        try wheel("wheel-empty-txt", mode: .tools, items: [item("readme.txt")], highlight: nil)
        try wheel("wheel-keyboard-focus", mode: .conversions, items: [item("photo.jpg")], highlight: 1, keyboard: true)
        try wheel("wheel-two-petals-zip", mode: .conversions, items: [item("project.zip")], highlight: 0)
        try wheel("wheel-one-petal-gif", mode: .tools, items: [item("loop.gif")], highlight: nil)

        // Tool windows, settings, onboarding, HUD, shelf
        let sample = dir.appendingPathComponent("_sample.png")
        OnboardingController.writeSample(to: sample)
        try saveSwiftUI(SettingsView(store: .shared, page: .shortcuts, onHotKeyChange: {}, showOnboarding: {}), to: dir.appendingPathComponent("settings-shortcuts.png"))
        try saveSwiftUI(SettingsView(store: .shared, page: .about, onHotKeyChange: {}, showOnboarding: {}), to: dir.appendingPathComponent("settings-about.png"))
        let ob = OnboardingController(); ob.page = 1; ob.dragged = true
        try saveSwiftUI(OnboardingView(c: ob), to: dir.appendingPathComponent("onboarding-try-it.png"))
        try saveSwiftUI(ToolWindowPreviews.compress([sample]), to: dir.appendingPathComponent("tool-compress.png"), settle: 1.5)
        try saveSwiftUI(ToolWindowPreviews.crop([sample]), to: dir.appendingPathComponent("tool-crop.png"), settle: 1.0)
        try saveSwiftUI(KeyHintPreview.view(glyphs), to: dir.appendingPathComponent("key-hint.png"))
        let shelf = FloatShelf(); shelf.items = [sample, URL(fileURLWithPath: "/tmp/missing-file.mov")]; shelf.missing = [URL(fileURLWithPath: "/tmp/missing-file.mov")]
        try saveSwiftUI(FloatShelfView(shelf: shelf), to: dir.appendingPathComponent("float-shelf.png"))
        for (name, state) in [("hud-running", JobState.running), ("hud-done", .succeeded([sample])),
                              ("hud-error", .failed(message: "The file looks damaged. The original is unchanged.", details: ""))] {
            let job = JobQueue(maxConcurrent: 0).enqueue(title: "Converting to PNG", subject: "kyoto-trip.heic") { _ in [] }
            let m = HUDModel(job: job); m.state = state; m.progress = 0.62
            m.retry = {}
            try saveSwiftUI(HUDView(model: m), to: dir.appendingPathComponent("\(name).png"))
        }
        try? FileManager.default.removeItem(at: sample)
    }

    static func save(_ view: NSView, background: Bool, to url: URL) throws {
        let w = NSWindow(contentRect: NSRect(origin: .zero, size: view.frame.size), styleMask: .borderless, backing: .buffered, defer: false)
        let root = NSView(frame: NSRect(origin: .zero, size: view.frame.size))
        root.wantsLayer = true
        if background { root.layer?.backgroundColor = NSColor(srgbRed: 0.42, green: 0.36, blue: 0.86, alpha: 1).cgColor }
        view.frame = root.bounds
        root.addSubview(view)
        w.contentView = root
        try write(root, to: url)
    }

    static func saveSwiftUI<V: View>(_ v: V, to url: URL, settle: TimeInterval = 0.3) throws {
        let host = NSHostingView(rootView: v.environment(\.colorScheme, .light))
        host.frame = NSRect(origin: .zero, size: host.fittingSize)
        let w = NSWindow(contentRect: host.frame, styleMask: .borderless, backing: .buffered, defer: false)
        w.appearance = NSAppearance(named: .aqua)
        w.contentView = host
        RunLoop.main.run(until: Date().addingTimeInterval(settle)) // let .task/.onAppear load
        host.frame.size = host.fittingSize
        try write(host, to: url)
    }

    static func write(_ v: NSView, to url: URL) throws {
        v.layoutSubtreeIfNeeded()
        guard let rep = v.bitmapImageRepForCachingDisplay(in: v.bounds) else { throw JobFailure("snapshot failed") }
        v.cacheDisplay(in: v.bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else { throw JobFailure("png failed") }
        try data.write(to: url)
        print("snapshot \(url.lastPathComponent) \(Int(v.bounds.width))x\(Int(v.bounds.height))")
    }
}
