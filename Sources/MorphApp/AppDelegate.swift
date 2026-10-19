import AppKit
import Combine
import Capabilities
import Jobs
import Engines
import DragKit
import ToolWindows
import A11y

final class AppDelegate: NSObject, NSApplicationDelegate, DragControllerDelegate {
    let store = SettingsStore.shared
    let drag = DragController()
    let hud = HUDController()
    let hotKey = HotKey()
    let services = ServicesProvider()
    let settingsWindow = SettingsWindowController()
    let helpWindow = HelpWindowController()
    let onboarding = OnboardingController()
    var statusMenu: StatusMenu?
    private var bag: Set<AnyCancellable> = []

    /// Hides AVIF/HEIC targets this macOS can't write (spec R5).
    lazy var registry = CapabilityRegistry(unavailableTargets: ImageEngine.unavailableTargets)

    func applicationDidFinishLaunching(_ note: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.appearance = NSAppearance(named: .aqua)

        statusMenu = StatusMenu()
        statusMenu?.openWheelForSelection = { [weak self] in self?.openWheelForFinderSelection() }
        statusMenu?.openSettings = { [weak self] in self?.settingsWindow.show() }
        statusMenu?.openHelp = { [weak self] in self?.helpWindow.show() }
        settingsWindow.onHotKeyChange = { [weak self] in self?.registerHotKey() }
        settingsWindow.showOnboarding = { [weak self] in self?.onboarding.show() }

        JobQueue.shared.maxConcurrent = store.maxConcurrentJobs
        store.$maxConcurrentJobs.sink { JobQueue.shared.maxConcurrent = $0 }.store(in: &bag)
        JobQueue.shared.onChange = { [weak self] job in self?.jobChanged(job) }

        drag.delegate = self
        drag.start()
        registerHotKey()
        hotKey.action = { [weak self] in self?.openWheelForFinderSelection() }

        services.open = { [weak self] urls in self?.drag.openKeyboard(urls: urls) }
        NSApp.servicesProvider = services
        NSUpdateDynamicServices()

        onboarding.startDrag = { [weak self] urls in self?.drag.beginDrag(urls: urls) }
        onboarding.onFinish = { [weak self] in self?.store.onboardingDone = true }
        if !store.onboardingDone { onboarding.show() }
    }

    func registerHotKey() { hotKey.register(code: store.hotKeyCode, modifiers: store.hotKeyModifiers) }

    func openWheelForFinderSelection() {
        let urls = FinderSelection.urls()
        guard !urls.isEmpty else {
            Announcer.say("Select one or more files in Finder first.")
            NSSound.beep()
            return
        }
        drag.openKeyboard(urls: urls)
    }

    // MARK: DragControllerDelegate

    var dragSettings: DragSettings { store.dragSettings }
    var isPaused: Bool { store.paused }

    func dragControllerDidStartDrag(_ c: DragController) {
        if store.showHint, store.hintCount < SettingsStore.hintLimit { store.hintCount += 1 }
    }

    func dragControllerDidOpenWheel(_ c: DragController, mode: WheelMode) { onboarding.noteWheelOpened() }

    func dragController(_ c: DragController, didChoose mode: WheelMode, target: String, items: [URL], anchor: NSPoint) {
        switch mode {
        case .actions:
            Actions.run(target, urls: items)
        case .conversions:
            enqueue(.convert(target: target), items: items)
        case .tools:
            if ToolWindows.needsWindow(tool: target, itemCount: items.count) {
                Task { @MainActor [weak self] in
                    ToolWindows.present(tool: target, items: items, anchor: anchor) { options in
                        self?.enqueue(.tool(id: target, options: options), items: items)
                    }
                }
            } else {
                enqueue(.tool(id: target, options: .none), items: items)
            }
        }
    }

    // MARK: Jobs

    private var operations: [UUID: (EngineOperation, [URL])] = [:]

    func enqueue(_ op: EngineOperation, items: [URL]) {
        let title = Engine.title(for: op, items: items)
        let subject = items.count > 1 ? "\(items.count) files" : items[0].lastPathComponent
        let job = JobQueue.shared.enqueue(title: title, subject: subject, itemCount: items.count) { ctx in
            try await Engine.perform(op, items: items, context: ctx)
        }
        operations[job.id] = (op, items)
    }

    func jobChanged(_ job: Job) {
        hud.retryProvider = { [weak self] j in
            guard let (op, items) = self?.operations[j.id] else { return nil }
            return { self?.enqueue(op, items: items) }
        }
        hud.update(job)
        if case .succeeded(let urls) = job.state {
            operations[job.id] = nil
            store.addRecent(urls, detail: job.title)
            onboarding.noteConverted(urls)
            if store.revealInFinder, !urls.isEmpty { NSWorkspace.shared.activateFileViewerSelecting(urls) }
        }
    }
}
