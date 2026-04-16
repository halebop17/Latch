import AppKit
import Combine

/// Central state machine.  All public methods must be called on the main thread.
final class AwakeManager: ObservableObject {

    // Singleton — accessed by AppIntents, CrowScheduleService, and StatusItemController.
    static let shared = AwakeManager()

    @Published private(set) var isActive: Bool = false
    @Published private(set) var fireDate: Date? = nil
    @Published private(set) var remainingSeconds: Int = 0
    @Published private(set) var activationReason: ActivationReason?

    private let caffeineService = CaffeineService()

    // Phase 2 services
    let batteryMonitor     = BatteryMonitor()
    let lowPowerMonitor    = LowPowerModeMonitor()
    let displayMonitor     = DisplayMonitor()

    private var countdownTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // Session tracking (Phase 3)
    private var sessionStartDate: Date?

    /// Holds the state when the user switches accounts so it can be resumed.
    private var suspendedSeconds: TimeInterval = -1
    private var suspendedReason: ActivationReason = .manual

    private init() {
        // Sync state when caffeinate exits externally (e.g. its -t timer fires)
        caffeineService.$isActive
            .receive(on: DispatchQueue.main)
            .sink { [weak self] active in
                guard let self else { return }
                if !active && self.isActive {
                    self.handleNaturalExpiry()
                }
            }
            .store(in: &cancellables)

        // Battery threshold
        batteryMonitor.$currentCapacity
            .receive(on: DispatchQueue.main)
            .sink { [weak self] capacity in self?.checkBatteryThreshold(capacity) }
            .store(in: &cancellables)

        // Low Power Mode
        lowPowerMonitor.$isLowPowerModeEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] lowPower in
                guard let self, lowPower, AppSettings.deactivateOnLowPowerMode else { return }
                if self.isActive { self.deactivate() }
            }
            .store(in: &cancellables)

        // External display connect/disconnect
        displayMonitor.$externalDisplayCount
            .receive(on: DispatchQueue.main)
            .sink { [weak self] count in self?.handleExternalDisplayChange(count) }
            .store(in: &cancellables)

        // Workspace session (fast-user-switching)
        registerWorkspaceObservers()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    // MARK: - Activation

    func activate(seconds: TimeInterval = 0, reason: ActivationReason = .manual) {
        caffeineService.start(
            seconds: seconds,
            allowDisplaySleep: AppSettings.allowDisplaySleep
        )
        isActive = true
        activationReason = reason
        sessionStartDate = Date()

        if seconds > 0 {
            fireDate = Date(timeIntervalSinceNow: seconds)
            remainingSeconds = Int(seconds)
            startCountdown()
        } else {
            fireDate = nil
            remainingSeconds = 0
        }

        batteryMonitor.startMonitoring()

        if AppSettings.notificationsEnabled {
            NotificationService.shared.notifyActivated(fireDate: fireDate)
        }
    }

    func activate(duration: ActivationDuration, reason: ActivationReason = .manual) {
        activate(seconds: duration.seconds, reason: reason)
    }

    func deactivate() {
        caffeineService.stop()
        finishDeactivation(sendNotification: true)
    }

    func toggle(duration: ActivationDuration = .indefinite) {
        isActive ? deactivate() : activate(duration: duration)
    }

    // MARK: - Private helpers

    private func handleNaturalExpiry() {
        finishDeactivation(sendNotification: true)
        if AppSettings.quitOnTimerExpiry {
            NSApplication.shared.terminate(nil)
        }
    }

    private func startCountdown() {
        stopCountdown()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self, let fire = self.fireDate else { return }
            let remaining = fire.timeIntervalSinceNow
            if remaining <= 0 {
                self.remainingSeconds = 0
                self.stopCountdown()
            } else {
                self.remainingSeconds = Int(remaining)
            }
        }
    }

    private func stopCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    private func finishDeactivation(sendNotification: Bool) {
        stopCountdown()

        // Record session before clearing state
        if let start = sessionStartDate {
            SessionLogService.shared.record(start: start, end: Date(), reason: activationReason ?? .manual)
            sessionStartDate = nil
        }

        isActive = false
        activationReason = nil
        fireDate = nil
        remainingSeconds = 0
        batteryMonitor.stopMonitoring()

        if sendNotification && AppSettings.notificationsEnabled {
            NotificationService.shared.notifyDeactivated()
        }
    }

    // MARK: - Battery threshold

    private func checkBatteryThreshold(_ capacity: Double) {
        guard isActive,
              AppSettings.batteryThresholdEnabled,
              capacity <= AppSettings.batteryThreshold
        else { return }
        deactivate()
    }

    // MARK: - External display

    private func handleExternalDisplayChange(_ count: Int) {
        guard AppSettings.activateOnExternalDisplay else { return }
        if count == 0 {
            if isActive { deactivate() }
        } else {
            if !isActive { activate(seconds: 0, reason: .externalDisplay) }
        }
    }

    // MARK: - Workspace / fast-user-switching

    private func registerWorkspaceObservers() {
        let wc = NSWorkspace.shared.notificationCenter
        wc.addObserver(self,
                       selector: #selector(sessionBecameActive),
                       name: NSWorkspace.sessionDidBecomeActiveNotification,
                       object: nil)
        wc.addObserver(self,
                       selector: #selector(sessionResignedActive),
                       name: NSWorkspace.sessionDidResignActiveNotification,
                       object: nil)
    }

    @objc private func sessionResignedActive() {
        guard AppSettings.deactivateOnUserSwitch, isActive else { return }
        suspendedSeconds = fireDate.map { max(0, $0.timeIntervalSinceNow) } ?? 0
        suspendedReason  = activationReason ?? .manual
        caffeineService.stop()
        finishDeactivation(sendNotification: false)
    }

    @objc private func sessionBecameActive() {
        guard AppSettings.deactivateOnUserSwitch, suspendedSeconds >= 0 else { return }
        activate(seconds: suspendedSeconds, reason: suspendedReason)
        suspendedSeconds = -1
    }
}
