import UserNotifications

/// Posts activate/deactivate notifications via UNUserNotificationCenter.
final class NotificationService {

    static let shared = NotificationService()
    private init() {}

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func notifyActivated(fireDate: Date?) {
        let content = UNMutableNotificationContent()
        content.title = "Latch is awake 🐙"
        if let fire = fireDate {
            // Absolute time — RelativeDateTimeFormatter yields "in 30 minutes",
            // which read as "…awake until in 30 minutes".
            let formatter = DateFormatter()
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            content.body = "Your Mac will stay awake until \(formatter.string(from: fire))."
        } else {
            content.body = "Your Mac will stay awake indefinitely."
        }
        post(content, identifier: "latch.activated")
    }

    func notifyDeactivated() {
        let content = UNMutableNotificationContent()
        content.title = "Latch went back to sleep 💤"
        content.body = "Your Mac can sleep normally again."
        post(content, identifier: "latch.deactivated")
    }

    func notifyProcessStarted(name: String) {
        let content = UNMutableNotificationContent()
        content.title = "Latch is awake 🐙"
        content.body = "Your Mac will stay awake until \(name) quits."
        post(content, identifier: "latch.activated")
    }

    func notifyProcessFinished(name: String) {
        let content = UNMutableNotificationContent()
        content.title = "\(name) finished 🐙"
        content.body = "Latch let go — your Mac can sleep normally again."
        post(content, identifier: "latch.processFinished")
    }

    // MARK: - Private

    private func post(_ content: UNMutableNotificationContent, identifier: String) {
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil  // deliver immediately
        )
        UNUserNotificationCenter.current().add(request)
    }
}
