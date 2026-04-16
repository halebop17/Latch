import Foundation
import Combine

/// Observes NSProcessInfo.isLowPowerModeEnabled via KVO.
final class LowPowerModeMonitor: ObservableObject {

    @Published private(set) var isLowPowerModeEnabled: Bool = false

    private var observation: NSKeyValueObservation?

    init() {
        isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
        observation = ProcessInfo.processInfo.observe(\.isLowPowerModeEnabled,
                                                       options: [.new]) { [weak self] info, _ in
            DispatchQueue.main.async {
                self?.isLowPowerModeEnabled = info.isLowPowerModeEnabled
            }
        }
    }

    deinit {
        observation?.invalidate()
    }
}
