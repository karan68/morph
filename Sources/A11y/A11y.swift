import Foundation
#if canImport(AppKit)
import AppKit

/// Design tokens from spec §5.4 (contrast ratios computed there: all text ≥ 4.9:1).
public enum Theme {
    public static func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
        NSColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: a)
    }
    public static let accent = rgb(0x5B47F5)        // white text on accent 5.73:1
    public static let accentInk = rgb(0x3B2BC4)     // on accentSoft 7.59:1
    public static let accentSoft = rgb(0xECE9FF)
    public static let teal = rgb(0x0C766C)          // success 5.5:1
    public static let tealSoft = rgb(0xE3F6F3)
    public static let danger = rgb(0xC62F2F)        // 5.46:1
    public static let ink = rgb(0x1C1B22)           // 17.08:1
    public static let ink2 = rgb(0x4F4D5C)          // 8.24:1
    public static let ink3 = rgb(0x6B6978)          // 5.36:1
    public static let petal = rgb(0xFBFBFE)         // label on petal 16.54:1
    public static let line = rgb(0x1C1B22, 0.1)
    public static let glass = rgb(0xFAFAFD, 0.74)
    public static let chip = rgb(0x1C1B22, 0.78)

    /// Radii: window 18 · panel 14 · control 8 · petal corner 12.
    public static let windowRadius: CGFloat = 18
    public static let panelRadius: CGFloat = 14
    public static let controlRadius: CGFloat = 8
}

/// VoiceOver announcements (spec §6 A2) via NSAccessibility.Notification.announcementRequested.
public enum Announcer {
    public static func say(_ text: String, priority: NSAccessibilityPriorityLevel = .high) {
        guard !text.isEmpty else { return }
        let element: Any = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible }) ?? NSApp as Any
        NSAccessibility.post(element: element, notification: .announcementRequested,
                             userInfo: [.announcement: text, .priority: priority.rawValue])
    }
}

/// System display preferences (spec §6 A8), observed live.
public final class DisplayOptions {
    public static let shared = DisplayOptions()
    public private(set) var reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    public private(set) var reduceTransparency = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
    public private(set) var increaseContrast = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
    public var onChange: [() -> Void] = []

    /// Solid, outlined wheel style (spec mockup 06-D) when either option is on.
    public var highContrastStyle: Bool { reduceTransparency || increaseContrast }

    private init() {
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
                                                          object: NSWorkspace.shared, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            self.reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            self.reduceTransparency = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
            self.increaseContrast = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
            self.onChange.forEach { $0() }
        }
    }
}

/// Icons rendered from Lucide (ISC) into template PNGs at build time (Resources/icons/<name>.png).
public enum Icons {
    private static var cache: [String: NSImage] = [:]
    public static func image(_ name: String, size: CGFloat = 16) -> NSImage? {
        let key = "\(name)@\(size)"
        if let i = cache[key] { return i }
        guard let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "icons"),
              let src = NSImage(contentsOf: url) else { return nil }
        let img = src.copy() as! NSImage
        img.size = NSSize(width: size, height: size)
        img.isTemplate = true
        cache[key] = img
        return img
    }

    /// Template image tinted with a colour (for drawing in custom views).
    public static func tinted(_ name: String, size: CGFloat, color: NSColor) -> NSImage? {
        guard let base = image(name, size: size) else { return nil }
        let out = NSImage(size: base.size)
        out.lockFocus()
        base.draw(in: NSRect(origin: .zero, size: base.size))
        color.set()
        NSRect(origin: .zero, size: base.size).fill(using: .sourceAtop)
        out.unlockFocus()
        return out
    }
}
#endif
