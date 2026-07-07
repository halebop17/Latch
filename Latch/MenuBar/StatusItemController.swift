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
        loadIconStyle()
        configureButton()
        updateIcon(active: false)
        bindToManager()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iconStyleChanged),
            name: MenuBarIconStyle.didChangeNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Button setup

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(handleClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        // Note: deliberately NOT .terminationOnRemoval — an accidental ⌘-drag off
        // the menu bar must not silently quit the app. Quit lives in the menu.
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

        // Status header (disabled — informational)
        let header = NSMenuItem(title: statusLine(), action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        if awakeManager.isActive {
            let off = NSMenuItem(title: "Deactivate", action: #selector(deactivateAction), keyEquivalent: "")
            off.target = self
            menu.addItem(off)

            if awakeManager.fireDate != nil {
                let extend = NSMenuItem(title: "Extend by 15 Minutes",
                                        action: #selector(extendAction), keyEquivalent: "")
                extend.target = self
                menu.addItem(extend)
            }
        }

        menu.addItem(.separator())

        // Duration presets
        for duration in ActivationDuration.allCases {
            let item = NSMenuItem(
                title: duration.displayName,
                action: #selector(selectDuration(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = duration
            // Checkmark on the preset this session was started with
            if awakeManager.isActive && awakeManager.activatedSeconds == duration.seconds {
                item.state = .on
            }
            menu.addItem(item)
        }

        // Until… — the next few full hours
        let untilItem = NSMenuItem(title: "Until…", action: nil, keyEquivalent: "")
        let untilMenu = NSMenu()
        for date in Self.upcomingFullHours(count: 8) {
            let item = NSMenuItem(title: Self.untilTitle(for: date),
                                  action: #selector(selectUntil(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = date
            untilMenu.addItem(item)
        }
        untilItem.submenu = untilMenu
        menu.addItem(untilItem)

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
            title: "Quit Latch",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))

        return menu
    }

    private func statusLine() -> String {
        guard awakeManager.isActive else { return "Inactive" }
        var line = awakeManager.fireDate != nil
            ? "Active — \(formatTime(awakeManager.remainingSeconds)) remaining"
            : "Active — indefinitely"
        if let reason = awakeManager.activationReason, reason != .manual {
            line += "  ·  \(reason.rawValue)"
        }
        return line
    }

    private static func upcomingFullHours(count: Int) -> [Date] {
        let calendar = Calendar.current
        var dates: [Date] = []
        var cursor = Date()
        for _ in 0..<count {
            guard let next = calendar.nextDate(after: cursor,
                                               matching: DateComponents(minute: 0, second: 0),
                                               matchingPolicy: .nextTime) else { break }
            dates.append(next)
            cursor = next
        }
        return dates
    }

    private static let untilFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    private static func untilTitle(for date: Date) -> String {
        let time = untilFormatter.string(from: date)
        return Calendar.current.isDateInToday(date) ? time : "Tomorrow \(time)"
    }

    @objc private func selectDuration(_ sender: NSMenuItem) {
        guard let duration = sender.representedObject as? ActivationDuration else { return }
        awakeManager.activate(duration: duration)
    }

    @objc private func selectUntil(_ sender: NSMenuItem) {
        guard let date = sender.representedObject as? Date else { return }
        let seconds = date.timeIntervalSinceNow
        guard seconds > 0 else { return }
        awakeManager.activate(seconds: seconds)
    }

    @objc private func deactivateAction() {
        awakeManager.deactivate()
    }

    @objc private func extendAction() {
        awakeManager.extend()
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

    // Glyphs from the asset catalog for the user-selected style — template images
    // (black + alpha), so macOS adapts them to light/dark menu bars automatically.
    // Active: filled glyph. Inactive: outline glyph (full/empty-cup metaphor).
    private var imageActive: NSImage?
    private var imageInactive: NSImage?

    private func loadIconStyle() {
        let style = MenuBarIconStyle(rawValue: AppSettings.menuBarIconStyle) ?? .octopus
        imageActive = Self.templateImage(named: style.activeAssetName)
        imageInactive = Self.templateImage(named: style.inactiveAssetName)
    }

    private static func templateImage(named name: String) -> NSImage? {
        let img = NSImage(named: name)
        img?.isTemplate = true
        return img
    }

    @objc private func iconStyleChanged() {
        loadIconStyle()
        updateIcon(active: awakeManager.isActive)
        if awakeManager.remainingSeconds > 0 {
            updateCountdown(awakeManager.remainingSeconds)
        }
    }

    private func updateIcon(active: Bool) {
        guard let button = statusItem.button else { return }
        button.image = active ? imageActive : imageInactive
        button.imagePosition = .imageLeft
        // Clear any countdown title when just flipping the icon
        if !awakeManager.isActive || awakeManager.remainingSeconds == 0 {
            button.title = ""
        }
        button.toolTip = active
            ? "Latch is keeping your Mac awake — click to deactivate"
            : "Click to keep your Mac awake"
    }

    private func updateCountdown(_ remaining: Int) {
        guard let button = statusItem.button else { return }
        if remaining > 0 {
            button.image = imageActive
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
