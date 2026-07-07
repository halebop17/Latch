import AppKit
import Combine

/// Monitors CrowSchedules and auto-activates/deactivates Latch accordingly.
/// Checks every 30 seconds. Only deactivates if the current session was started by a schedule.
final class CrowScheduleService: ObservableObject {

    static let shared = CrowScheduleService()

    @Published var schedules: [CrowSchedule] = []

    private let defaultsKey = "com.latch.crowSchedules"
    private var timer: Timer?

    /// True while the current window's auto-activation was cancelled (by the user,
    /// battery threshold, or Low Power Mode). Prevents re-activating every 30 s.
    private var suppressedUntilWindowEnds = false
    private var didAutoActivateForWindow = false

    private init() { load() }

    // MARK: - Monitoring

    func startMonitoring() {
        guard timer == nil else { return }
        tick()
        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - CRUD

    func add(_ schedule: CrowSchedule) {
        schedules.append(schedule)
        save()
    }

    func remove(at offsets: IndexSet) {
        schedules.remove(atOffsets: offsets)
        save()
    }

    func update(_ schedule: CrowSchedule) {
        guard let idx = schedules.firstIndex(where: { $0.id == schedule.id }) else { return }
        schedules[idx] = schedule
        save()
    }

    // MARK: - Private

    private func tick() {
        let inWindow = schedules.contains { $0.isCurrentlyActive() }
        let manager  = AwakeManager.shared

        guard inWindow else {
            suppressedUntilWindowEnds = false
            didAutoActivateForWindow = false
            if manager.isActive && manager.activationReason == .schedule {
                manager.deactivate()
            }
            return
        }

        guard !manager.isActive else { return }

        // We already activated for this window, yet Latch is off again —
        // the user (or battery / Low Power Mode protection) turned it off.
        // Don't fight that decision until the window ends.
        if didAutoActivateForWindow {
            suppressedUntilWindowEnds = true
        }
        guard !suppressedUntilWindowEnds else { return }

        manager.activate(seconds: 0, reason: .schedule)
        didAutoActivateForWindow = true
    }

    private func load() {
        guard let data    = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([CrowSchedule].self, from: data)
        else { return }
        schedules = decoded
    }

    private func save() {
        if let encoded = try? JSONEncoder().encode(schedules) {
            UserDefaults.standard.set(encoded, forKey: defaultsKey)
        }
    }
}
