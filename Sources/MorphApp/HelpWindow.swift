import AppKit
import SwiftUI
import A11y

/// "Keyboard & accessibility help" (menu item, spec mockup 01 / §6 A12).
final class HelpWindowController {
    private var window: NSWindow?
    func show() {
        if window == nil {
            let w = NSWindow(contentViewController: NSHostingController(rootView: HelpView().environment(\.colorScheme, .light)))
            w.title = "Keyboard & Accessibility"
            w.styleMask = [.titled, .closable]
            w.appearance = NSAppearance(named: .aqua)
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct HelpView: View {
    let s = SettingsStore.shared
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Using Morph without dragging").font(.system(size: 15, weight: .bold)).accessibilityAddTraits(.isHeader)
            line(s.hotKeyDescription, "Open the wheel for the files selected in Finder")
            line("Services", "Finder ▸ right-click ▸ Services ▸ Convert with Morph…")
            Divider()
            Text("In the wheel").font(.system(size: 15, weight: .bold)).accessibilityAddTraits(.isHeader)
            line("← → ↑ ↓", "Move between choices (Home / End jump to first / last)")
            line("Return", "Apply the highlighted choice")
            line("Esc", "Cancel — nothing is saved")
            line("\(s.convertKey.glyph) \(s.toolsKey.glyph) \(s.actionsKey.glyph)", "Switch between Convert, Tools and Actions")
            Divider()
            Text("While dragging").font(.system(size: 15, weight: .bold)).accessibilityAddTraits(.isHeader)
            line(s.convertKey.glyph, "Tap once — the wheel stays open until you drop (turn on Hold-to-open in Settings if you prefer)")
            line("Drop", "On a petal to apply; on the centre or outside to cancel")
            Divider()
            Text("Morph follows Reduce Motion, Increase Contrast and Reduce Transparency from System Settings, and announces every step to VoiceOver.")
                .foregroundColor(Color(Theme.ink2)).fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .frame(width: 520)
        .foregroundColor(Color(Theme.ink))
        .font(.system(size: 13))
    }

    func line(_ k: String, _ t: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(k).font(.system(size: 12, weight: .semibold)).frame(minWidth: 90, alignment: .leading)
            Text(t).fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}
