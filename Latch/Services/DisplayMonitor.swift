import AppKit
import Combine

/// Monitors screen configuration changes to detect external display connect/disconnect.
final class DisplayMonitor: ObservableObject {

    @Published private(set) var externalDisplayCount: Int = 0

    init() {
        externalDisplayCount = Self.countExternalDisplays()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Private

    @objc private func screensChanged() {
        DispatchQueue.main.async {
            self.externalDisplayCount = Self.countExternalDisplays()
        }
    }

    /// Count screens that are not the built-in display.
    /// Uses CGDisplayIsBuiltin — localizedName is translated per system language
    /// (e.g. "Integriertes Retina-Display" on German systems), so string matching
    /// would misclassify the built-in panel as external.
    private static func countExternalDisplays() -> Int {
        NSScreen.screens.filter { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                return false
            }
            return CGDisplayIsBuiltin(CGDirectDisplayID(number.uint32Value)) == 0
        }.count
    }
}
