import Foundation

/// Handles the custom URL scheme  rooster://
///
/// Examples:
///   rooster:///activate               → indefinite
///   rooster:///activate?minutes=30    → 30 minutes
///   rooster:///activate?seconds=90    → 90 seconds
///   rooster:///activate?hours=2       → 2 hours
///   rooster:///deactivate
///   rooster:///toggle
enum URLSchemeHandler {

    static func handle(url: URL, awakeManager: AwakeManager) {
        guard url.scheme?.lowercased() == "rooster" else { return }

        let action = url.lastPathComponent
        let params = queryParams(from: url)

        DispatchQueue.main.async {
            switch action {
            case "activate":
                if let raw = params["seconds"], let v = Double(raw) {
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
