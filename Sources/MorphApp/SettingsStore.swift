import AppKit
import Combine
import Carbon.HIToolbox
import Capabilities
import DragKit

/// One finished job shown under "Recent" in the menu (spec mockup 01).
struct RecentItem: Codable, Equatable {
    let path: String
    let detail: String
    let date: Date
}

/// All user preferences, stored only in this Mac's UserDefaults.
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()
    private let d = UserDefaults.standard

    @Published var convertKey: ModifierKey { didSet { save("key.conversions", convertKey.rawValue) } }
    @Published var toolsKey: ModifierKey { didSet { save("key.tools", toolsKey.rawValue) } }
    @Published var actionsKey: ModifierKey { didSet { save("key.actions", actionsKey.rawValue) } }
    @Published var hotKeyCode: Int { didSet { save("hotkey.code", hotKeyCode) } }
    @Published var hotKeyModifiers: Int { didSet { save("hotkey.mods", hotKeyModifiers) } }
    @Published var showHint: Bool { didSet { save("hint.show", showHint) } }
    @Published var hintCount: Int { didSet { save("hint.count", hintCount) } }
    @Published var tickSound: Bool { didSet { save("a11y.tick", tickSound) } }
    @Published var haptics: Bool { didSet { save("a11y.haptics", haptics) } }
    @Published var holdToOpen: Bool { didSet { save("a11y.hold", holdToOpen) } }
    @Published var maxConcurrentJobs: Int { didSet { save("jobs.max", maxConcurrentJobs) } }
    @Published var revealInFinder: Bool { didSet { save("output.reveal", revealInFinder) } }
    @Published var paused: Bool { didSet { save("paused", paused) } }
    @Published var onboardingDone: Bool { didSet { save("onboarding.done", onboardingDone) } }
    @Published private(set) var recent: [RecentItem] = []

    /// Spec mockup 12: "Shown for your first 10 drags".
    static let hintLimit = 10

    private static func key(_ d: UserDefaults, _ k: String, _ def: ModifierKey) -> ModifierKey {
        d.string(forKey: k).flatMap(ModifierKey.init) ?? def
    }

    private init() {
        let d = UserDefaults.standard
        convertKey = Self.key(d, "key.conversions", .shift)
        toolsKey = Self.key(d, "key.tools", .command)
        actionsKey = Self.key(d, "key.actions", .control)
        hotKeyCode = d.object(forKey: "hotkey.code") as? Int ?? kVK_Space
        hotKeyModifiers = d.object(forKey: "hotkey.mods") as? Int ?? (controlKey | optionKey)
        showHint = d.object(forKey: "hint.show") as? Bool ?? true
        hintCount = d.integer(forKey: "hint.count")
        tickSound = d.object(forKey: "a11y.tick") as? Bool ?? true
        haptics = d.object(forKey: "a11y.haptics") as? Bool ?? true
        holdToOpen = d.bool(forKey: "a11y.hold")
        maxConcurrentJobs = d.object(forKey: "jobs.max") as? Int ?? 2
        revealInFinder = d.object(forKey: "output.reveal") as? Bool ?? true
        paused = d.bool(forKey: "paused")
        onboardingDone = d.bool(forKey: "onboarding.done")
        if let data = d.data(forKey: "recent"), let r = try? JSONDecoder().decode([RecentItem].self, from: data) { recent = r }
    }

    private func save(_ k: String, _ v: Any) { d.set(v, forKey: k) }

    var dragSettings: DragSettings {
        var s = DragSettings()
        s.keys = [.conversions: convertKey, .tools: toolsKey, .actions: actionsKey]
        s.holdToOpen = holdToOpen
        s.tickSound = tickSound
        s.haptics = haptics
        s.showHint = showHint && hintCount < Self.hintLimit
        return s
    }

    /// Every wheel needs a different modifier key (spec mockup 12).
    func setKey(_ k: ModifierKey, for mode: WheelMode) {
        let current: [WheelMode: ModifierKey] = [.conversions: convertKey, .tools: toolsKey, .actions: actionsKey]
        if let clash = current.first(where: { $0.value == k && $0.key != mode })?.key, let mine = current[mode] {
            assign(mine, to: clash)
        }
        assign(k, to: mode)
    }

    private func assign(_ k: ModifierKey, to mode: WheelMode) {
        switch mode {
        case .conversions: convertKey = k
        case .tools: toolsKey = k
        case .actions: actionsKey = k
        }
    }

    func addRecent(_ urls: [URL], detail: String) {
        var r = recent
        for u in urls.reversed() { r.insert(RecentItem(path: u.path, detail: detail, date: Date()), at: 0) }
        recent = Array(r.prefix(10))
        if let data = try? JSONEncoder().encode(recent) { d.set(data, forKey: "recent") }
    }

    var hotKeyDescription: String {
        var s = ""
        if hotKeyModifiers & controlKey != 0 { s += "⌃" }
        if hotKeyModifiers & optionKey != 0 { s += "⌥" }
        if hotKeyModifiers & shiftKey != 0 { s += "⇧" }
        if hotKeyModifiers & cmdKey != 0 { s += "⌘" }
        return s + KeyNames.name(for: hotKeyCode)
    }
}

enum KeyNames {
    static func name(for code: Int) -> String {
        switch code {
        case kVK_Space: return "Space"
        case kVK_Return: return "Return"
        case kVK_Tab: return "Tab"
        default:
            let map: [Int: String] = [kVK_ANSI_A: "A", kVK_ANSI_B: "B", kVK_ANSI_C: "C", kVK_ANSI_D: "D", kVK_ANSI_E: "E", kVK_ANSI_F: "F",
                                      kVK_ANSI_G: "G", kVK_ANSI_H: "H", kVK_ANSI_I: "I", kVK_ANSI_J: "J", kVK_ANSI_K: "K", kVK_ANSI_L: "L",
                                      kVK_ANSI_M: "M", kVK_ANSI_N: "N", kVK_ANSI_O: "O", kVK_ANSI_P: "P", kVK_ANSI_Q: "Q", kVK_ANSI_R: "R",
                                      kVK_ANSI_S: "S", kVK_ANSI_T: "T", kVK_ANSI_U: "U", kVK_ANSI_V: "V", kVK_ANSI_W: "W", kVK_ANSI_X: "X",
                                      kVK_ANSI_Y: "Y", kVK_ANSI_Z: "Z", kVK_ANSI_0: "0", kVK_ANSI_1: "1", kVK_ANSI_2: "2", kVK_ANSI_3: "3",
                                      kVK_ANSI_4: "4", kVK_ANSI_5: "5", kVK_ANSI_6: "6", kVK_ANSI_7: "7", kVK_ANSI_8: "8", kVK_ANSI_9: "9"]
            return map[code] ?? "Key \(code)"
        }
    }
}
