import Foundation

/// Why Rooster was activated — used for session logging and smart auto-deactivation.
enum ActivationReason: String, Codable {
    case manual          = "Manual"
    case schedule        = "Crow Schedule"
    case urlScheme       = "URL Scheme"
    case externalDisplay = "External Display"
    case launch          = "On Launch"
    case hotkey          = "Hotkey (⌥⌘K)"
    case shortcut        = "Shortcut"
}
