import AppKit
import Combine

/// Monitors CrowSchedules and auto-activates/deactivates Rooster accordingly.
/// Checks every 30 seconds. Only deactivates if the current session was started by a schedule.
final class CrowScheduleService: ObservableObject {

    static let shared = CrowScheduleService()

    @Published var schedules: [CrowSchedule] = []

    private let defaultsKey = "com.rooster.crowSchedules"
    private var timer: Timer?

    private init() { load() }

    // MARK: - Monitoring

    func startMonitoring() {
        guard timer == nil else { return }
        tick()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.tick()
        }
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

        if inWindow && !manager.isActive {
            manager.activate(seconds: 0, reason: .schedule)
        } else if !inWindow && manager.isActive && manager.activationReason == .schedule {
            manager.deactivate()
        }
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
