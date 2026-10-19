import AppKit
import SwiftUI
import ServiceManagement
import Carbon.HIToolbox
import Capabilities
import DragKit
import A11y

enum SettingsPage: String, CaseIterable {
    case general = "General", shortcuts = "Shortcuts", output = "Output", accessibility = "Accessibility", privacy = "Privacy", about = "About"
    var icon: String {
        switch self {
        case .general: return "settings"; case .shortcuts: return "keyboard"; case .output: return "folder"
        case .accessibility: return "accessibility"; case .privacy: return "shield"; case .about: return "info"
        }
    }
}

final class SettingsWindowController {
    private var window: NSWindow?
    var onHotKeyChange: (() -> Void)?
    var showOnboarding: (() -> Void)?

    func show(page: SettingsPage = .shortcuts) {
        if window == nil {
            let view = SettingsView(store: .shared, page: page, onHotKeyChange: { [weak self] in self?.onHotKeyChange?() },
                                    showOnboarding: { [weak self] in self?.showOnboarding?() })
            let w = NSWindow(contentViewController: NSHostingController(rootView: view.environment(\.colorScheme, .light)))
            w.title = "Morph Settings"
            w.styleMask = [.titled, .closable, .fullSizeContentView]
            w.titlebarAppearsTransparent = true
            w.appearance = NSAppearance(named: .aqua)
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct SettingsView: View {
    @ObservedObject var store: SettingsStore
    @State var page: SettingsPage
    let onHotKeyChange: () -> Void
    let showOnboarding: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(SettingsPage.allCases, id: \.self) { p in
                    Button { page = p } label: {
                        HStack(spacing: 9) {
                            Image(nsImage: Icons.image(p.icon, size: 15) ?? NSImage()).renderingMode(.template)
                            Text(p.rawValue).font(.system(size: 13, weight: .medium))
                            Spacer()
                        }
                        .padding(.horizontal, 10).padding(.vertical, 7)
                        .foregroundColor(page == p ? .white : Color(Theme.ink))
                        .background(RoundedRectangle(cornerRadius: 7).fill(page == p ? Color(Theme.accent) : .clear))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(page == p ? [.isButton, .isSelected] : .isButton)
                }
                Spacer()
            }
            .padding(.top, 54).padding(.horizontal, 10)
            .frame(width: 200)
            .background(Color(Theme.rgb(0xF0F0F6, 0.8)))
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    switch page {
                    case .general: GeneralPage(store: store, showOnboarding: showOnboarding)
                    case .shortcuts: ShortcutsPage(store: store, onHotKeyChange: onHotKeyChange)
                    case .output: OutputPage(store: store)
                    case .accessibility: AccessibilityPage(store: store)
                    case .privacy: PrivacyPage()
                    case .about: AboutPage()
                    }
                }
                .padding(.horizontal, 26).padding(.vertical, 22)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: 860, height: 640)
        .foregroundColor(Color(Theme.ink))
        .font(.system(size: 13))
    }
}

// MARK: Building blocks (mockup 12 grouped rows)

struct PageTitle: View {
    let title: String, subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 18, weight: .bold)).accessibilityAddTraits(.isHeader)
            Text(subtitle).foregroundColor(Color(Theme.ink3))
        }
    }
}

struct SettingsGroup<Content: View>: View {
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(spacing: 0) { content() }
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(Theme.line)))
            .padding(.top, 14)
    }
}

struct SettingRow<Trailing: View>: View {
    let title: String
    var detail: String? = nil
    var last = false
    @ViewBuilder let trailing: () -> Trailing
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 13, weight: .semibold))
                    if let d = detail { Text(d).font(.system(size: 11.5)).foregroundColor(Color(Theme.ink3)) }
                }
                Spacer()
                trailing()
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            if !last { Divider() }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: Shortcuts (spec mockup 12)

struct ShortcutsPage: View {
    @ObservedObject var store: SettingsStore
    let onHotKeyChange: () -> Void
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        PageTitle(title: "Shortcuts", subtitle: "Tap a key while dragging a file to open a wheel.")
        SettingsGroup {
            keyRow("Conversions", "Formats you can convert to", .conversions, store.convertKey)
            keyRow("File tools", "Compress, trim, crop, metadata…", .tools, store.toolsKey)
            keyRow("File actions", "AirDrop, Float, Copy, Move, Copy Path, Terminal", .actions, store.actionsKey, last: true)
        }
        SettingsGroup {
            SettingRow(title: "Open wheel for Finder selection", detail: "Keyboard alternative to dragging") {
                Text(recording ? "Type a shortcut…" : store.hotKeyDescription)
                    .font(.system(size: 12, weight: .semibold)).padding(.horizontal, 8).frame(height: 24)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(Theme.rgb(0xFAFAFE))))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(Theme.line)))
                Button(recording ? "Cancel" : "Record") { recording ? stopRecording() : startRecording() }
            }
            SettingRow(title: "Show key hint while dragging", detail: "Shown for your first \(SettingsStore.hintLimit) drags") {
                Toggle("", isOn: $store.showHint).toggleStyle(.switch).labelsHidden()
            }
            SettingRow(title: "Tick sound on highlight") { Toggle("", isOn: $store.tickSound).toggleStyle(.switch).labelsHidden() }
            SettingRow(title: "Hold-to-open", detail: "Open the wheel only while the key is held (off = tap once, stays open)", last: true) {
                Toggle("", isOn: $store.holdToOpen).toggleStyle(.switch).labelsHidden()
            }
        }
        Text("Each wheel needs a different modifier key. Fn and Caps Lock can't be used.")
            .font(.system(size: 12)).foregroundColor(Color(Theme.ink3)).padding(.top, 12)
    }

    func keyRow(_ title: String, _ detail: String, _ mode: WheelMode, _ key: ModifierKey, last: Bool = false) -> some View {
        SettingRow(title: title, detail: detail, last: last) {
            Picker("", selection: Binding(get: { key }, set: { store.setKey($0, for: mode) })) {
                ForEach(ModifierKey.allCases, id: \.self) { k in Text("\(k.glyph)  \(k.name)").tag(k) }
            }
            .labelsHidden().frame(width: 140)
            .accessibilityLabel("\(title) key")
        }
    }

    func startRecording() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { e in
            let mods = e.modifierFlags.intersection([.control, .option, .command, .shift])
            guard !mods.intersection([.control, .option, .command]).isEmpty else { NSSound.beep(); return nil }
            store.hotKeyCode = Int(e.keyCode)
            store.hotKeyModifiers = HotKey.carbonModifiers(mods)
            stopRecording()
            onHotKeyChange()
            Announcer.say("Shortcut set to \(store.hotKeyDescription)")
            return nil
        }
    }

    func stopRecording() {
        recording = false
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
    }
}

// MARK: Other pages

struct GeneralPage: View {
    @ObservedObject var store: SettingsStore
    let showOnboarding: () -> Void
    @State private var loginItem = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        PageTitle(title: "General", subtitle: "Morph lives in the menu bar and stays out of the way until the next drag.")
        SettingsGroup {
            SettingRow(title: "Pause Morph", detail: "Ignore drags until resumed") { Toggle("", isOn: $store.paused).toggleStyle(.switch).labelsHidden() }
            SettingRow(title: "Open at login", detail: loginError ?? "Start Morph when you log in", last: true) {
                Toggle("", isOn: Binding(get: { loginItem }, set: { on in
                    do {
                        if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                        loginItem = on; loginError = nil
                    } catch { loginError = "macOS didn't allow this: \(error.localizedDescription)" }
                })).toggleStyle(.switch).labelsHidden()
            }
        }
        SettingsGroup {
            SettingRow(title: "Try it once", detail: "Replay the first-run practice", last: true) { Button("Show", action: showOnboarding) }
        }
    }
}

struct OutputPage: View {
    @ObservedObject var store: SettingsStore
    var body: some View {
        PageTitle(title: "Output", subtitle: "New files are always saved beside the original. Originals are never changed.")
        SettingsGroup {
            SettingRow(title: "Reveal results in Finder", detail: "Select new files in Finder when a job finishes") {
                Toggle("", isOn: $store.revealInFinder).toggleStyle(.switch).labelsHidden()
            }
            SettingRow(title: "Jobs at the same time", detail: "Other jobs wait in a queue", last: true) {
                Stepper("\(store.maxConcurrentJobs)", value: $store.maxConcurrentJobs, in: 1...4)
            }
        }
        SettingsGroup {
            SettingRow(title: "Conversions", detail: "photo.heic → photo.png") { EmptyView() }
            SettingRow(title: "Tools", detail: "harbor.mov → harbor Trimmed.mov · Compress turns WAV into FLAC") { EmptyView() }
            SettingRow(title: "Extract", detail: "project.zip → “project Extracted” folder") { EmptyView() }
            SettingRow(title: "Name already taken", detail: "photo 2.png, photo 3.png… — nothing is ever overwritten", last: true) { EmptyView() }
        }
    }
}

struct AccessibilityPage: View {
    @ObservedObject var store: SettingsStore
    var body: some View {
        PageTitle(title: "Accessibility", subtitle: "Everything works with the keyboard and VoiceOver.")
        SettingsGroup {
            SettingRow(title: "Tick sound on highlight") { Toggle("", isOn: $store.tickSound).toggleStyle(.switch).labelsHidden() }
            SettingRow(title: "Haptic feedback", detail: "Force Touch trackpads") { Toggle("", isOn: $store.haptics).toggleStyle(.switch).labelsHidden() }
            SettingRow(title: "Hold-to-open", detail: "Off = tap a key once and the wheel stays open", last: true) {
                Toggle("", isOn: $store.holdToOpen).toggleStyle(.switch).labelsHidden()
            }
        }
        SettingsGroup {
            let d = DisplayOptions.shared
            SettingRow(title: "Reduce Motion", detail: "Follows System Settings") { Text(d.reduceMotion ? "On" : "Off").foregroundColor(Color(Theme.ink2)) }
            SettingRow(title: "Increase Contrast", detail: "Follows System Settings") { Text(d.increaseContrast ? "On" : "Off").foregroundColor(Color(Theme.ink2)) }
            SettingRow(title: "Reduce Transparency", detail: "Follows System Settings", last: true) { Text(d.reduceTransparency ? "On" : "Off").foregroundColor(Color(Theme.ink2)) }
        }
        Button("Open Accessibility Settings…") {
            if let u = URL(string: "x-apple.systempreferences:com.apple.preference.universalaccess") { NSWorkspace.shared.open(u) }
        }
        .padding(.top, 12)
    }
}

struct PrivacyPage: View {
    var body: some View {
        PageTitle(title: "Privacy", subtitle: "Morph runs on this Mac. Files are never uploaded.")
        SettingsGroup {
            SettingRow(title: "No uploads", detail: "Every conversion and tool runs locally. Morph has no server.") { EmptyView() }
            SettingRow(title: "No analytics or tracking", detail: "Nothing about you or your files is collected.") { EmptyView() }
            SettingRow(title: "Finder access", detail: "Only when you use the keyboard shortcut, to read the current Finder selection (macOS asks once).") { EmptyView() }
            SettingRow(title: "Settings stay here", detail: "Preferences and recent files are stored only on this Mac.", last: true) { EmptyView() }
        }
    }
}

struct AboutPage: View {
    var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev" }
    var build: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "" }
    var body: some View {
        HStack(spacing: 14) {
            if let l = StatusMenu.logo(size: 56) { Image(nsImage: l) }
            VStack(alignment: .leading, spacing: 3) {
                Text("Morph").font(.system(size: 22, weight: .bold))
                Text("Version \(version) (\(build)) · M1 friends alpha").foregroundColor(Color(Theme.ink2))
            }
        }
        SettingsGroup {
            SettingRow(title: "FFmpeg", detail: "This software uses libraries from the FFmpeg project under the LGPLv2.1. Source and build configuration are published with each release.") { EmptyView() }
            SettingRow(title: "Other components", detail: "LAME (LGPL), libvpx, libwebp, libvorbis, libogg, libopus, libarchive (BSD-style), Lucide icons (ISC).", last: true) {
                Button("Licenses…") {
                    if let u = Bundle.main.url(forResource: "THIRD_PARTY_NOTICES", withExtension: "md") { NSWorkspace.shared.open(u) }
                }
            }
        }
    }
}
