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
    /// Uses NSScreen's localizedName; built-in panels are typically "Built-in Retina Display"
    /// or match the "Color LCD" / "Built-in" prefix. We exclude those.
    private static func countExternalDisplays() -> Int {
        NSScreen.screens.filter { screen in
            let name = screen.localizedName.lowercased()
            return !name.contains("built-in") && !name.contains("color lcd")
        }.count
    }
}
