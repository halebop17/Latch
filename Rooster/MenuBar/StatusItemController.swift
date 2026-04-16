import AppKit
import Combine

/// Manages the NSStatusItem (menu bar icon, click handling, countdown display).
final class StatusItemController: NSObject {

    private let statusItem: NSStatusItem
    private let awakeManager: AwakeManager
    private var cancellables = Set<AnyCancellable>()

    init(awakeManager: AwakeManager) {
        self.awakeManager = awakeManager
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configureButton()
        updateIcon(active: false)
        bindToManager()
    }

    // MARK: - Button setup

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(handleClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        // NSStatusItemBehavior.terminationOnRemoval: dragging icon out of menu bar quits app
        statusItem.behavior = .terminationOnRemoval
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        let isRightClick = event.type == .rightMouseUp
        let isCtrlClick  = event.modifierFlags.contains(.control)

        if isRightClick || isCtrlClick {
            showMenu()
        } else {
            awakeManager.toggle()
        }
    }

    // MARK: - Menu

    private func showMenu() {
        let menu = buildMenu()
        menu.delegate = self
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        // menu is cleared in menuDidClose via NSMenuDelegate
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        // Duration presets
        for duration in ActivationDuration.allCases {
            let item = NSMenuItem(
                title: duration.displayName,
                action: #selector(selectDuration(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = duration
            // Show checkmark on the currently active duration
            if awakeManager.isActive,
               let fire = awakeManager.fireDate {
                let remaining = fire.timeIntervalSinceNow
                if abs(remaining - duration.seconds) < 5 {
                    item.state = .on
                }
            } else if awakeManager.isActive && duration == .indefinite {
                item.state = .on
            }
            menu.addItem(item)
        }

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(
            title: "Quit Rooster",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))

        return menu
    }

    @objc private func selectDuration(_ sender: NSMenuItem) {
        guard let duration = sender.representedObject as? ActivationDuration else { return }
        awakeManager.activate(duration: duration)
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.show()
    }

    // MARK: - State binding

    private func bindToManager() {
        awakeManager.$isActive
            .receive(on: DispatchQueue.main)
            .sink { [weak self] active in self?.updateIcon(active: active) }
            .store(in: &cancellables)

        awakeManager.$remainingSeconds
            .receive(on: DispatchQueue.main)
            .sink { [weak self] remaining in self?.updateCountdown(remaining) }
            .store(in: &cancellables)
    }

    // MARK: - Icon & title

    // Active state: full-color PNG from asset catalog
    private static let imageActive: NSImage? = NSImage(named: "StatusActive")

    // Inactive state: SF Symbol template — adapts automatically to dark/light menu bar
    private static let imageInactive: NSImage? = {
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        let img = NSImage(systemSymbolName: "moon.zzz.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        img?.isTemplate = true
        return img
    }()

    private func updateIcon(active: Bool) {
        guard let button = statusItem.button else { return }
        button.image = active ? Self.imageActive : Self.imageInactive
        button.imagePosition = .imageLeft
        // Clear any countdown title when just flipping the icon
        if !awakeManager.isActive || awakeManager.remainingSeconds == 0 {
            button.title = ""
        }
        button.toolTip = active
            ? "Rooster is keeping your Mac awake — click to deactivate"
            : "Click to keep your Mac awake"
    }

    private func updateCountdown(_ remaining: Int) {
        guard let button = statusItem.button else { return }
        if remaining > 0 {
            button.image = Self.imageActive
            button.imagePosition = .imageLeft
            button.title = " \(formatTime(remaining))"
        } else {
            button.title = ""
        }
    }

    private func formatTime(_ totalSeconds: Int) -> String {
        let h = totalSeconds / 3600
        let m = (totalSeconds % 3600) / 60
        let s = totalSeconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%d:%02d", m, s)
        }
    }
}

// MARK: - NSMenuDelegate

extension StatusItemController: NSMenuDelegate {
    func menuDidClose(_ menu: NSMenu) {
        // Remove menu so left-click goes back to toggle behaviour
        statusItem.menu = nil
    }
}
