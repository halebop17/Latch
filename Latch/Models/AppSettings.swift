import Foundation

/// Persistent user preferences backed by UserDefaults.
struct AppSettings {

    // MARK: - Keys
    private enum Keys {
        static let activateOnLaunch             = "com.latch.activateOnLaunch"
        static let allowDisplaySleep            = "com.latch.allowDisplaySleep"
        static let defaultDurationSeconds       = "com.latch.defaultDurationSeconds"
        static let quitOnTimerExpiry            = "com.latch.quitOnTimerExpiry"
        static let batteryThresholdEnabled      = "com.latch.batteryThresholdEnabled"
        static let batteryThreshold             = "com.latch.batteryThreshold"
        static let deactivateOnLowPowerMode     = "com.latch.deactivateOnLowPowerMode"
        static let activateOnExternalDisplay    = "com.latch.activateOnExternalDisplay"
        static let deactivateOnUserSwitch       = "com.latch.deactivateOnUserSwitch"
        static let notificationsEnabled         = "com.latch.notificationsEnabled"
        static let deactivateOnFocus            = "com.latch.deactivateOnFocus"
        static let playCrowSound                = "com.latch.playCrowSound"
        static let menuBarIconStyle             = "com.latch.menuBarIconStyle"
        static let hotkeyEnabled                = "com.latch.hotkeyEnabled"
        static let hotkeyKeyCode                = "com.latch.hotkeyKeyCode"
        static let hotkeyModifiers              = "com.latch.hotkeyModifiers"
        static let hotkeyDisplay                = "com.latch.hotkeyDisplay"
    }

    // MARK: - Properties

    static var activateOnLaunch: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.activateOnLaunch) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.activateOnLaunch) }
    }

    /// When true, caffeinate runs with -i only (idle sleep prevented, display may still sleep).
    static var allowDisplaySleep: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.allowDisplaySleep) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.allowDisplaySleep) }
    }

    /// Default duration in seconds; 0 means indefinite.
    static var defaultDurationSeconds: TimeInterval {
        get {
            let v = UserDefaults.standard.double(forKey: Keys.defaultDurationSeconds)
            return v > 0 ? v : 0
        }
        set { UserDefaults.standard.set(newValue, forKey: Keys.defaultDurationSeconds) }
    }

    static var quitOnTimerExpiry: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.quitOnTimerExpiry) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.quitOnTimerExpiry) }
    }

    static var batteryThresholdEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.batteryThresholdEnabled) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.batteryThresholdEnabled) }
    }

    /// Battery percentage (0–100) below which Latch auto-deactivates.
    static var batteryThreshold: Double {
        get {
            let v = UserDefaults.standard.double(forKey: Keys.batteryThreshold)
            return v > 0 ? v : 20
        }
        set { UserDefaults.standard.set(newValue, forKey: Keys.batteryThreshold) }
    }

    static var deactivateOnLowPowerMode: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.deactivateOnLowPowerMode) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.deactivateOnLowPowerMode) }
    }

    static var activateOnExternalDisplay: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.activateOnExternalDisplay) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.activateOnExternalDisplay) }
    }

    static var deactivateOnUserSwitch: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.deactivateOnUserSwitch) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.deactivateOnUserSwitch) }
    }

    static var notificationsEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.notificationsEnabled) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.notificationsEnabled) }
    }

    /// Deactivate while a macOS Focus mode is engaged (needs Full Disk Access).
    static var deactivateOnFocusMode: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.deactivateOnFocus) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.deactivateOnFocus) }
    }

    static var playCrowSound: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.playCrowSound) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.playCrowSound) }
    }

    /// Raw value of MenuBarIconStyle.
    static var menuBarIconStyle: String {
        get { UserDefaults.standard.string(forKey: Keys.menuBarIconStyle) ?? MenuBarIconStyle.octopus.rawValue }
        set { UserDefaults.standard.set(newValue, forKey: Keys.menuBarIconStyle) }
    }

    // MARK: - Global hotkey

    static var hotkeyEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Keys.hotkeyEnabled) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Keys.hotkeyEnabled) }
    }

    /// Carbon virtual key code; nil = never customized (GlobalHotkeyService falls back to ⌥⌘K).
    static var hotkeyKeyCode: Int? {
        get { UserDefaults.standard.object(forKey: Keys.hotkeyKeyCode) as? Int }
        set { UserDefaults.standard.set(newValue, forKey: Keys.hotkeyKeyCode) }
    }

    /// Carbon modifier mask; nil = never customized.
    static var hotkeyModifiers: Int? {
        get { UserDefaults.standard.object(forKey: Keys.hotkeyModifiers) as? Int }
        set { UserDefaults.standard.set(newValue, forKey: Keys.hotkeyModifiers) }
    }

    /// Human-readable combo, e.g. "⌃⇧⌘K", for display in Settings.
    static var hotkeyDisplay: String {
        get { UserDefaults.standard.string(forKey: Keys.hotkeyDisplay) ?? "⌥⌘K" }
        set { UserDefaults.standard.set(newValue, forKey: Keys.hotkeyDisplay) }
    }
}
