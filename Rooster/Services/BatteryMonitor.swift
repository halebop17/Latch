import Foundation
import IOKit.ps

/// Polls the system battery via IOKit's power source API.
/// Publishes the current capacity (0–100) and whether a charger is connected.
final class BatteryMonitor: ObservableObject {

    @Published private(set) var currentCapacity: Double = 100
    @Published private(set) var isOnAC: Bool = true

    private var timer: Timer?

    func startMonitoring() {
        guard timer == nil else { return }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Private

    private func refresh() {
        guard
            let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
            let sources  = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
            let source   = sources.first,
            let desc     = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue()
                               as? [String: Any]
        else {
            // Desktop Mac or no battery info — treat as always on AC at 100%
            currentCapacity = 100
            isOnAC = true
            return
        }

        if let capacity = desc[kIOPSCurrentCapacityKey] as? Int {
            currentCapacity = Double(capacity)
        }

        let powerSource = desc[kIOPSPowerSourceStateKey] as? String
        isOnAC = (powerSource == kIOPSACPowerValue)
    }
}
