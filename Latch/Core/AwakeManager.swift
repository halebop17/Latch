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
    /// The requested length of the current session (0 = indefinite) — drives menu checkmarks.
    @Published private(set) var activatedSeconds: TimeInterval = 0
    /// Name of the app/process this session is latched onto, if any (drives the menu label).
    @Published private(set) var watchedProcessName: String?
    /// PID this session is latched onto, if any (drives the menu checkmark; disambiguates same-named apps).
    @Published private(set) var watchedPID: pid_t?

    private let caffeineService = CaffeineService()
    private let processMonitor  = ProcessMonitor()

    // Phase 2 services
    let batteryMonitor     = BatteryMonitor()
    let lowPowerMonitor    = LowPowerModeMonitor()
    let displayMonitor     = DisplayMonitor()
    let focusMonitor       = FocusModeMonitor()

    private var countdownTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // Session tracking (Phase 3)
    private var sessionStartDate: Date?

    /// Holds the state when the user switches accounts so it can be resumed.
    private var suspendedSeconds: TimeInterval = -1
    private var suspendedReason: ActivationReason = .manual
    private var suspendedWatchPID: pid_t?
    private var suspendedWatchName: String = ""

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

        // Focus mode (reading it requires Full Disk Access; no-op without)
        focusMonitor.$isFocusActive
            .receive(on: DispatchQueue.main)
            .sink { [weak self] focused in
                guard let self, focused, AppSettings.deactivateOnFocusMode else { return }
                if self.isActive { self.deactivate() }
            }
            .store(in: &cancellables)

        // Workspace session (fast-user-switching)
        registerWorkspaceObservers()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    // MARK: - Activation

    func activate(seconds: TimeInterval = 0, reason: ActivationReason = .manual, notify: Bool = true) {
        guard caffeineService.start(
            seconds: seconds,
            allowDisplaySleep: AppSettings.allowDisplaySleep
        ) else { return }
        // A new session supersedes the previous one: log the old span before it's
        // overwritten, and drop any process-watch it left behind.
        recordCurrentSessionIfActive()
        processMonitor.cancel()
        watchedProcessName = nil
        watchedPID = nil
        isActive = true
        activationReason = reason
        activatedSeconds = seconds
        sessionStartDate = Date()

        if seconds > 0 {
            fireDate = Date(timeIntervalSinceNow: seconds)
            remainingSeconds = Int(seconds)
            startCountdown()
        } else {
            stopCountdown()
            fireDate = nil
            remainingSeconds = 0
        }

        batteryMonitor.startMonitoring()
        focusMonitor.startMonitoring()

        if AppSettings.playCrowSound {
            CrowSoundPlayer.play()
        }
        if notify && AppSettings.notificationsEnabled {
            NotificationService.shared.notifyActivated(fireDate: fireDate)
        }
    }

    func activate(duration: ActivationDuration, reason: ActivationReason = .manual) {
        activate(seconds: duration.seconds, reason: reason)
    }

    /// Stay awake indefinitely until the process with `pid` exits, then deactivate.
    /// No-ops if the process isn't alive (nothing to wait for).
    func activate(watchingPID pid: pid_t, name: String, notify: Bool = true) {
        guard pid > 0, kill(pid, 0) == 0 else { return }
        activate(seconds: 0, reason: .process, notify: false)   // clears any prior watch; suppress the generic notice
        watchedProcessName = name
        watchedPID = pid
        let started = processMonitor.watch(pid: pid) { [weak self] in
            self?.handleWatchedProcessExit(name: name)
        }
        // Vanishingly rare: the process died between the guard above and here.
        // Don't leave an indefinite session with nothing to end it.
        if !started { handleWatchedProcessExit(name: name); return }
        if notify && AppSettings.notificationsEnabled {
            NotificationService.shared.notifyProcessStarted(name: name)   // tailored "until <app> quits"
        }
    }

    /// Adds time to the current timed session without restarting or re-notifying.
    func extend(by extra: TimeInterval = 15 * 60) {
        guard isActive, let fire = fireDate else { return }
        let newSeconds = max(0, fire.timeIntervalSinceNow) + extra
        guard caffeineService.start(
            seconds: newSeconds,
            allowDisplaySleep: AppSettings.allowDisplaySleep
        ) else { return }
        fireDate = Date(timeIntervalSinceNow: newSeconds)
        remainingSeconds = Int(newSeconds)
        activatedSeconds = newSeconds
        startCountdown()
    }

    func deactivate() {
        // Guard against double deactivation (e.g. quit-on-expiry → applicationWillTerminate,
        // or latch:///deactivate while idle), which would post spurious notifications.
        guard isActive else { return }
        caffeineService.stop()
        finishDeactivation(sendNotification: true)
    }

    func toggle() {
        // Off → on uses the configurable default duration (0 = indefinite).
        isActive ? deactivate() : activate(seconds: AppSettings.defaultDurationSeconds)
    }

    // MARK: - Private helpers

    private func handleNaturalExpiry() {
        finishDeactivation(sendNotification: true)
        if AppSettings.quitOnTimerExpiry {
            NSApplication.shared.terminate(nil)
        }
    }

    /// The process we latched onto has exited — let the Mac sleep and say which app finished.
    private func handleWatchedProcessExit(name: String) {
        guard isActive else { return }
        caffeineService.stop()
        finishDeactivation(sendNotification: false)   // suppress the generic notice…
        if AppSettings.notificationsEnabled {
            NotificationService.shared.notifyProcessFinished(name: name)   // …send a tailored one
        }
    }

    private func startCountdown() {
        stopCountdown()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self, let fire = self.fireDate else { return }
            let remaining = fire.timeIntervalSinceNow
            if remaining <= 0 {
                self.remainingSeconds = 0
                self.stopCountdown()
            } else {
                self.remainingSeconds = Int(remaining)
            }
        }
        // .common keeps the menu bar countdown ticking while menus are open
        // (scheduledTimer's .default mode is paused during menu tracking).
        RunLoop.main.add(timer, forMode: .common)
        countdownTimer = timer
    }

    private func stopCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    /// Logs the in-progress session (if any) to the session log, then clears its start
    /// marker so it can't be double-counted.  Called both on deactivation and when one
    /// session supersedes another.
    private func recordCurrentSessionIfActive() {
        guard isActive, let start = sessionStartDate else { return }
        let detail = (activationReason == .process) ? watchedProcessName : nil
        SessionLogService.shared.record(start: start, end: Date(),
                                        reason: activationReason ?? .manual, detail: detail)
        sessionStartDate = nil
    }

    private func finishDeactivation(sendNotification: Bool) {
        stopCountdown()
        processMonitor.cancel()
        recordCurrentSessionIfActive()

        isActive = false
        activationReason = nil
        watchedProcessName = nil
        watchedPID = nil
        fireDate = nil
        remainingSeconds = 0
        activatedSeconds = 0
        batteryMonitor.stopMonitoring()
        focusMonitor.stopMonitoring()

        if sendNotification && AppSettings.notificationsEnabled {
            NotificationService.shared.notifyDeactivated()
        }
    }

    // MARK: - Battery threshold

    private func checkBatteryThreshold(_ capacity: Double) {
        guard isActive,
              AppSettings.batteryThresholdEnabled,
              !batteryMonitor.isOnAC,  // drain protection only matters on battery power
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
        // min 1s: a timer that expired during the switch must not resume as indefinite
        // (0 means "indefinite" to activate(seconds:)).
        suspendedSeconds   = fireDate.map { max(1, $0.timeIntervalSinceNow) } ?? 0
        suspendedReason    = activationReason ?? .manual
        suspendedWatchPID  = (activationReason == .process) ? watchedPID : nil
        suspendedWatchName = watchedProcessName ?? ""
        caffeineService.stop()
        finishDeactivation(sendNotification: false)
    }

    @objc private func sessionBecameActive() {
        guard AppSettings.deactivateOnUserSwitch, suspendedSeconds >= 0 else { return }
        // Resume silently to mirror the suppressed suspend notification.
        if suspendedReason == .process {
            // Re-establish the process-watch; if it died while switched away,
            // activate(watchingPID:) no-ops rather than starting an unstoppable session.
            if let pid = suspendedWatchPID {
                activate(watchingPID: pid, name: suspendedWatchName, notify: false)
            }
        } else {
            activate(seconds: suspendedSeconds, reason: suspendedReason, notify: false)
        }
        suspendedSeconds  = -1
        suspendedWatchPID = nil
    }
}
