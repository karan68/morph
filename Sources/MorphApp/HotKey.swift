import AppKit
import Carbon.HIToolbox

/// Global shortcut (default ⌃⌥Space) for the non-drag path (spec §6 A3). Carbon hotkeys need no
/// Accessibility permission.
final class HotKey {
    private var ref: EventHotKeyRef?
    private var handler: EventHandlerRef?
    var action: (() -> Void)?

    func register(code: Int, modifiers: Int) {
        unregister()
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, user in
            guard let user = user else { return noErr }
            let me = Unmanaged<HotKey>.fromOpaque(user).takeUnretainedValue()
            DispatchQueue.main.async { me.action?() }
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handler)
        let id = EventHotKeyID(signature: OSType(0x4D52_5048), id: 1) // "MRPH"
        RegisterEventHotKey(UInt32(code), UInt32(modifiers), id, GetApplicationEventTarget(), 0, &ref)
    }

    func unregister() {
        if let r = ref { UnregisterEventHotKey(r); ref = nil }
        if let h = handler { RemoveEventHandler(h); handler = nil }
    }

    /// NSEvent modifier flags → Carbon modifier mask.
    static func carbonModifiers(_ f: NSEvent.ModifierFlags) -> Int {
        var m = 0
        if f.contains(.control) { m |= controlKey }
        if f.contains(.option) { m |= optionKey }
        if f.contains(.shift) { m |= shiftKey }
        if f.contains(.command) { m |= cmdKey }
        return m
    }
}

/// Reads the current Finder selection via Apple Events (needs one-time Automation consent:
/// NSAppleEventsUsageDescription in Info.plist).
enum FinderSelection {
    static func urls() -> [URL] {
        let src = """
        tell application "Finder"
            set out to {}
            repeat with i in (get selection as alias list)
                set end of out to POSIX path of i
            end repeat
            return out
        end tell
        """
        var err: NSDictionary?
        guard let result = NSAppleScript(source: src)?.executeAndReturnError(&err) else { return [] }
        var urls: [URL] = []
        if result.numberOfItems > 0 {
            for i in 1...result.numberOfItems {
                if let p = result.atIndex(i)?.stringValue { urls.append(URL(fileURLWithPath: p)) }
            }
        } else if let p = result.stringValue {
            urls.append(URL(fileURLWithPath: p))
        }
        return urls
    }
}

/// Finder ▸ Services ▸ "Convert with Morph…" (spec §6 A3), declared under NSServices in Info.plist.
final class ServicesProvider: NSObject {
    var open: (([URL]) -> Void)?

    @objc func convertWithMorph(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        let urls = (pboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? []
        guard !urls.isEmpty else { error.pointee = "No files were selected." as NSString; return }
        DispatchQueue.main.async { self.open?(urls) }
    }
}
