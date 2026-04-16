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
        content.title = "Rooster is awake 🐓"
        if let fire = fireDate {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            let relative = formatter.localizedString(for: fire, relativeTo: Date())
            content.body = "Your Mac will stay awake until \(relative)."
        } else {
            content.body = "Your Mac will stay awake indefinitely."
        }
        post(content, identifier: "rooster.activated")
    }

    func notifyDeactivated() {
        let content = UNMutableNotificationContent()
        content.title = "Rooster went back to sleep 💤"
        content.body = "Your Mac can sleep normally again."
        post(content, identifier: "rooster.deactivated")
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
