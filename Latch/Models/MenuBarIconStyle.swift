import Foundation

/// The user-selectable menu bar icon set. Raw values are persisted in UserDefaults.
enum MenuBarIconStyle: String, CaseIterable, Identifiable {
    case octopus   // default
    case meerkat
    case owl

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .octopus: return "Octopus"
        case .meerkat: return "Meerkat"
        case .owl:     return "Night Owl"
        }
    }

    var activeAssetName: String {
        switch self {
        case .octopus: return "StatusActiveOctopus"
        case .meerkat: return "StatusActiveMeerkat"
        case .owl:     return "StatusActiveOwl"
        }
    }

    var inactiveAssetName: String {
        switch self {
        case .octopus: return "StatusInactiveOctopus"
        case .meerkat: return "StatusInactiveMeerkat"
        case .owl:     return "StatusInactiveOwl"
        }
    }

    /// Posted when the user picks a different style in Settings.
    static let didChangeNotification = Notification.Name("com.latch.menuBarIconStyleChanged")
}
