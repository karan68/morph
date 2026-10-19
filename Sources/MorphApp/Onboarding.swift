import AppKit
import SwiftUI
import ImageIO
import DragKit
import A11y

/// Spec mockup 13: "Try it once" first-run practice. Page 1 introduces Morph, page 2 is the hands-on practice
/// with a sample file, page 3 shows the keyboard path and where Morph lives.
final class OnboardingController: ObservableObject {
    @Published var page = 0
    @Published var dragged = false
    @Published var wheelOpened = false
    @Published var converted = false
    private var window: NSWindow?
    let sample: URL
    var startDrag: (([URL]) -> Void)?
    var onFinish: (() -> Void)?

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Morph/Try it once")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        sample = dir.appendingPathComponent("try-me.png")
        if !FileManager.default.fileExists(atPath: sample.path) { Self.writeSample(to: sample) }
    }

    func show() {
        page = 0; dragged = false; wheelOpened = false; converted = false
        if window == nil {
            let w = NSWindow(contentViewController: NSHostingController(rootView: OnboardingView(c: self).environment(\.colorScheme, .light)))
            w.styleMask = [.titled, .closable, .fullSizeContentView]
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.title = "Welcome to Morph"
            w.appearance = NSAppearance(named: .aqua)
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func close() { window?.orderOut(nil); onFinish?() }

    func noteWheelOpened() { if page == 1, dragged { wheelOpened = true; Announcer.say("Step 2 done. Now drop on a format.") } }
    func noteConverted(_ urls: [URL]) {
        guard page == 1, urls.contains(where: { $0.deletingLastPathComponent() == sample.deletingLastPathComponent() }) else { return }
        converted = true
        Announcer.say("Done. The new file was saved beside the sample.")
    }

    /// Generated sample image (original art: soft gradient disc).
    static func writeSample(to url: URL) {
        let w = 512, h = 512
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
        let colors = [CGColor(red: 1, green: 0.95, blue: 0.77, alpha: 1), CGColor(red: 0.95, green: 0.7, blue: 0.24, alpha: 1), CGColor(red: 0.48, green: 0.3, blue: 0.07, alpha: 1)] as CFArray
        let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors, locations: [0, 0.45, 1])!
        ctx.drawRadialGradient(g, startCenter: CGPoint(x: 180, y: 330), startRadius: 0, endCenter: CGPoint(x: 256, y: 256), endRadius: 300, options: [.drawsAfterEndLocation])
        guard let img = ctx.makeImage(), let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(dest, img, nil)
        CGImageDestinationFinalize(dest)
    }
}

struct OnboardingView: View {
    @ObservedObject var c: OnboardingController

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                playground.frame(width: 450)
                Divider()
                steps.frame(width: 450)
            }
            .frame(height: 520)
            HStack {
                Text("Step \(c.page + 1) of 3").foregroundColor(Color(Theme.ink3))
                Spacer()
                if c.page < 2 { Button("Skip") { c.close() }.buttonStyle(OnbButton()) }
                Button(c.page < 2 ? "Continue" : "Done") { if c.page < 2 { c.page += 1 } else { c.close() } }
                    .buttonStyle(OnbButton(primary: true)).keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Color.white.opacity(0.7))
        }
        .frame(width: 900)
        .foregroundColor(Color(Theme.ink))
    }

    var playground: some View {
        ZStack {
            LinearGradient(colors: [Color(Theme.rgb(0xEFEAFF)), Color(Theme.rgb(0xE2F6F6)), Color(Theme.rgb(0xFDEEE6))], startPoint: .topLeading, endPoint: .bottomTrailing)
            if c.page == 1 {
                VStack(spacing: 6) {
                    if let img = NSImage(contentsOf: c.sample) {
                        Image(nsImage: img).resizable().frame(width: 72, height: 72).clipShape(RoundedRectangle(cornerRadius: 10))
                            .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
                    }
                    Text("try-me.png").font(.system(size: 12)).padding(.horizontal, 6).padding(.vertical, 1)
                        .background(RoundedRectangle(cornerRadius: 5).fill(Color(Theme.rgb(0x2F6FF0))))
                        .foregroundColor(.white)
                }
                .onDrag {
                    c.dragged = true
                    c.startDrag?([c.sample])
                    Announcer.say("Step 1 done. Now tap \(SettingsStore.shared.convertKey.name).")
                    return NSItemProvider(contentsOf: c.sample) ?? NSItemProvider()
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("try-me.png, sample file. Drag it, then tap \(SettingsStore.shared.convertKey.name).")
                .offset(x: -90, y: -120)
                Text("Drag me").font(.system(size: 13, weight: .semibold)).foregroundColor(Color(Theme.accentInk)).offset(x: 30, y: -150)
                    .accessibilityHidden(true)
            } else {
                if let l = StatusMenu.logo(size: 120) { Image(nsImage: l).accessibilityHidden(true) }
            }
        }
    }

    @ViewBuilder var steps: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                ForEach(0..<3) { i in Capsule().fill(i == c.page ? Color(Theme.accent) : Color(Theme.ink).opacity(0.2)).frame(width: i == c.page ? 20 : 7, height: 7) }
            }
            .accessibilityHidden(true)
            switch c.page {
            case 0:
                Text("Welcome to Morph").font(.system(size: 24, weight: .bold)).padding(.top, 18).accessibilityAddTraits(.isHeader)
                Text("Convert, compress and trim files right where you are. Start dragging a file and tap a key — a wheel of choices appears around your pointer.")
                    .font(.system(size: 14)).foregroundColor(Color(Theme.ink2)).padding(.top, 8).fixedSize(horizontal: false, vertical: true)
                keyLine(SettingsStore.shared.convertKey.glyph, "Convert to another format").padding(.top, 18)
                keyLine(SettingsStore.shared.toolsKey.glyph, "Tools: compress, trim, crop, metadata")
                keyLine(SettingsStore.shared.actionsKey.glyph, "Actions: AirDrop, Float, Copy, Move, Copy Path, Terminal")
                privacy.padding(.top, 18)
            case 1:
                Text("Try it once").font(.system(size: 24, weight: .bold)).padding(.top, 18).accessibilityAddTraits(.isHeader)
                Text("Morph has no window to open. You use it in the middle of a drag.").font(.system(size: 14)).foregroundColor(Color(Theme.ink2)).padding(.top, 8)
                step(1, done: c.dragged, now: !c.dragged, "Drag the sample file", "Any file, from Finder or your desktop")
                step(2, done: c.wheelOpened, now: c.dragged && !c.wheelOpened, "Tap \(SettingsStore.shared.convertKey.glyph) while still dragging", "The wheel appears around your pointer and stays open")
                step(3, done: c.converted, now: c.wheelOpened && !c.converted, "Drop on JPG", "The new file is saved beside the original")
                privacy.padding(.top, 16)
            default:
                Text("You're set").font(.system(size: 24, weight: .bold)).padding(.top, 18).accessibilityAddTraits(.isHeader)
                Text("Morph lives in the menu bar. Click its icon for recent files, the Float shelf, settings and help.")
                    .font(.system(size: 14)).foregroundColor(Color(Theme.ink2)).padding(.top, 8).fixedSize(horizontal: false, vertical: true)
                keyLine(SettingsStore.shared.hotKeyDescription, "Open the wheel for the Finder selection — no drag needed").padding(.top, 18)
                keyLine("↑↓", "Choose with the arrow keys, Return to apply, Esc to cancel")
                keyLine("⚙︎", "Change the keys in Settings ▸ Shortcuts")
                privacy.padding(.top, 18)
            }
            Spacer()
        }
        .padding(.horizontal, 32).padding(.vertical, 34)
    }

    var privacy: some View {
        HStack(spacing: 8) {
            Image(nsImage: Icons.image("shield", size: 16) ?? NSImage()).renderingMode(.template)
            Text("No uploads. Morph never connects to the internet to process files.").font(.system(size: 13, weight: .semibold))
        }
        .foregroundColor(Color(Theme.teal))
        .accessibilityElement(children: .combine)
    }

    func keyLine(_ k: String, _ t: String) -> some View {
        HStack(spacing: 10) {
            Text(k).font(.system(size: 12, weight: .semibold)).frame(minWidth: 26, minHeight: 24).padding(.horizontal, 4)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white).shadow(color: .black.opacity(0.25), radius: 0, y: 1))
            Text(t).font(.system(size: 13))
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    func step(_ n: Int, done: Bool, now: Bool, _ title: String, _ sub: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(done ? "✓" : "\(n)").font(.system(size: 12, weight: .bold)).frame(width: 26, height: 26)
                .background(Circle().fill(done ? Color(Theme.teal) : now ? Color(Theme.accent) : Color(Theme.ink).opacity(0.07)))
                .foregroundColor(done || now ? .white : Color(Theme.ink))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(sub).font(.system(size: 12)).foregroundColor(Color(Theme.ink3))
            }
        }
        .padding(.vertical, 12)
        .overlay(Divider(), alignment: .bottom)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(n): \(title). \(done ? "Done" : now ? "Current step" : "Not started")")
    }
}

struct OnbButton: ButtonStyle {
    var primary = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 13, weight: .medium)).padding(.horizontal, 12).frame(height: 28)
            .foregroundColor(primary ? .white : Color(Theme.ink))
            .background(RoundedRectangle(cornerRadius: 8).fill(primary ? Color(Theme.accent) : Color(Theme.ink).opacity(0.07)))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
