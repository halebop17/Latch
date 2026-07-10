import AppKit

/// Handles the custom URL scheme  latch://
///
/// Examples:
///   latch:///activate               → indefinite
///   latch:///activate?minutes=30    → 30 minutes
///   latch:///activate?seconds=90    → 90 seconds
///   latch:///activate?hours=2       → 2 hours
///   latch:///activate?waitpid=1234  → until process 1234 exits
///   latch:///deactivate
///   latch:///toggle
enum URLSchemeHandler {

    static func handle(url: URL, awakeManager: AwakeManager) {
        guard url.scheme?.lowercased() == "latch" else { return }

        let action = url.lastPathComponent
        let params = queryParams(from: url)

        DispatchQueue.main.async {
            switch action {
            case "activate":
                if let raw = params["waitpid"] {
                    // Malformed/overflow PID → no-op, never fall through to an indefinite session.
                    guard let pid = pid_t(raw), pid > 0 else { break }
                    let name = NSRunningApplication(processIdentifier: pid)?.localizedName ?? "process \(pid)"
                    awakeManager.activate(watchingPID: pid, name: name)
                } else if let raw = params["seconds"], let v = Double(raw) {
                    awakeManager.activate(seconds: ceil(v), reason: .urlScheme)
                } else if let raw = params["minutes"], let v = Double(raw) {
                    awakeManager.activate(seconds: ceil(v) * 60, reason: .urlScheme)
                } else if let raw = params["hours"], let v = Double(raw) {
                    awakeManager.activate(seconds: ceil(v) * 3600, reason: .urlScheme)
                } else {
                    awakeManager.activate(seconds: 0, reason: .urlScheme)
                }
            case "deactivate":
                awakeManager.deactivate()
            case "toggle":
                awakeManager.toggle()
            default:
                break
            }
        }
    }

    private static func queryParams(from url: URL) -> [String: String] {
        guard let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else {
            return [:]
        }
        return Dictionary(uniqueKeysWithValues: items.compactMap { item in
            item.value.map { (item.name, $0) }
        })
    }
}
