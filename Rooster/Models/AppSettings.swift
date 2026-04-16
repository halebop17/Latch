import Foundation

/// Persistent user preferences backed by UserDefaults.
struct AppSettings {

    // MARK: - Keys
    private enum Keys {
        static let activateOnLaunch             = "com.rooster.activateOnLaunch"
        static let allowDisplaySleep            = "com.rooster.allowDisplaySleep"
        static let defaultDurationSeconds       = "com.rooster.defaultDurationSeconds"
        static let quitOnTimerExpiry            = "com.rooster.quitOnTimerExpiry"
        static let batteryThresholdEnabled      = "com.rooster.batteryThresholdEnabled"
        static let batteryThreshold             = "com.rooster.batteryThreshold"
        static let deactivateOnLowPowerMode     = "com.rooster.deactivateOnLowPowerMode"
        static let activateOnExternalDisplay    = "com.rooster.activateOnExternalDisplay"
        static let deactivateOnUserSwitch       = "com.rooster.deactivateOnUserSwitch"
        static let notificationsEnabled         = "com.rooster.notificationsEnabled"
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

    /// Battery percentage (0–100) below which Rooster auto-deactivates.
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
}
