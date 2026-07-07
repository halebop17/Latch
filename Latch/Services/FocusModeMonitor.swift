import Foundation
import Combine

/// Watches the user's Focus state by reading macOS's Do Not Disturb assertions file.
///
/// ~/Library/DoNotDisturb/DB/Assertions.json lists the currently engaged Focus mode
/// (Do Not Disturb, Sleep, Work, …). The folder is privacy-protected: reading it
/// requires the user to grant Latch Full Disk Access. Without that grant
/// `isAvailable` stays false and the feature quietly does nothing.
final class FocusModeMonitor: ObservableObject {

    @Published private(set) var isFocusActive: Bool = false
    /// False when the assertions file cannot be read (usually: no Full Disk Access).
    @Published private(set) var isAvailable: Bool = false

    private var timer: Timer?
    private let assertionsURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/DoNotDisturb/DB/Assertions.json")

    func startMonitoring() {
        guard timer == nil else { return }
        refresh()
        let timer = Timer(timeInterval: 15, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    /// One-shot readability check so Settings can show the Full Disk Access hint.
    func probeAvailability() {
        refresh()
    }

    private func refresh() {
        guard let data = try? Data(contentsOf: assertionsURL) else {
            isAvailable = false
            isFocusActive = false
            return
        }
        isAvailable = true
        isFocusActive = Self.hasActiveAssertion(in: data)
    }

    /// The file contains {"data": [{"storeAssertionRecords": [...]}]} while a
    /// Focus mode is engaged; the records list is absent or empty otherwise.
    static func hasActiveAssertion(in data: Data) -> Bool {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entries = root["data"] as? [[String: Any]] else { return false }
        return entries.contains { entry in
            guard let records = entry["storeAssertionRecords"] as? [[String: Any]] else { return false }
            return !records.isEmpty
        }
    }
}
