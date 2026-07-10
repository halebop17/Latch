import Foundation

struct AwakeSession: Codable, Identifiable {
    var id: UUID = UUID()
    var startDate: Date
    var endDate: Date
    var durationSeconds: TimeInterval
    var reason: String
}

/// Persists the last 50 awake sessions in UserDefaults.
final class SessionLogService: ObservableObject {

    static let shared = SessionLogService()

    @Published private(set) var sessions: [AwakeSession] = []

    private let maxEntries = 50
    private let defaultsKey = "com.latch.sessionLog"

    private init() { load() }

    // MARK: - Public

    func record(start: Date, end: Date, reason: ActivationReason, detail: String? = nil) {
        let session = AwakeSession(
            startDate: start,
            endDate: end,
            durationSeconds: end.timeIntervalSince(start),
            reason: detail.map { "\(reason.rawValue) · \($0)" } ?? reason.rawValue
        )
        sessions.insert(session, at: 0)
        if sessions.count > maxEntries {
            sessions = Array(sessions.prefix(maxEntries))
        }
        save()
    }

    func clear() {
        sessions = []
        save()
    }

    // MARK: - Persistence

    private func load() {
        guard let data    = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([AwakeSession].self, from: data)
        else { return }
        sessions = decoded
    }

    private func save() {
        if let encoded = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(encoded, forKey: defaultsKey)
        }
    }
}
