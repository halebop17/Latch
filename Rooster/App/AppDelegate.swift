import AppKit
import Carbon

final class AppDelegate: NSObject, NSApplicationDelegate {

    let awakeManager = AwakeManager.shared
    var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Agent app: no Dock icon
        NSApp.setActivationPolicy(.accessory)

        statusItemController = StatusItemController(awakeManager: awakeManager)

        // Phase 3: global hotkey ⌥⌘K
        GlobalHotkeyService.shared.onToggle = { [weak self] in
            self?.awakeManager.toggle()
        }
        GlobalHotkeyService.shared.register()

        // Phase 3: Crow Schedule background monitoring
        CrowScheduleService.shared.startMonitoring()

        // Request notification permission if the user has it enabled
        if AppSettings.notificationsEnabled {
            NotificationService.shared.requestAuthorization()
        }

        // Activate on launch if the user opted in
        if AppSettings.activateOnLaunch {
            awakeManager.activate(seconds: AppSettings.defaultDurationSeconds, reason: .launch)
        }

        // Register for rooster:// URL scheme events
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:replyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        SettingsWindowController.shared.show()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        GlobalHotkeyService.shared.unregister()
        awakeManager.deactivate()
    }

    // MARK: - URL Scheme

    @objc private func handleGetURLEvent(
        _ event: NSAppleEventDescriptor,
        replyEvent: NSAppleEventDescriptor
    ) {
        guard
            let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
            let url = URL(string: urlString)
        else { return }
        URLSchemeHandler.handle(url: url, awakeManager: awakeManager)
    }
}
