import ServiceManagement

/// Wraps SMAppService for toggling login-item registration on macOS 13+.
enum LoginItemManager {

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Latch: LoginItemManager failed — %@", error.localizedDescription)
        }
    }
}
