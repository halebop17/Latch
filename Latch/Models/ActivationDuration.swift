import Foundation

/// Preset durations for keeping the Mac awake.
enum ActivationDuration: CaseIterable, Identifiable {
    case minutes5
    case minutes15
    case minutes30
    case hour1
    case hours2
    case hours5
    case indefinite

    var id: Self { self }

    /// Duration in seconds. Returns 0 for indefinite.
    var seconds: TimeInterval {
        switch self {
        case .minutes5:   return 5 * 60
        case .minutes15:  return 15 * 60
        case .minutes30:  return 30 * 60
        case .hour1:      return 60 * 60
        case .hours2:     return 2 * 60 * 60
        case .hours5:     return 5 * 60 * 60
        case .indefinite: return 0
        }
    }

    var displayName: String {
        switch self {
        case .minutes5:   return "5 Minutes"
        case .minutes15:  return "15 Minutes"
        case .minutes30:  return "30 Minutes"
        case .hour1:      return "1 Hour"
        case .hours2:     return "2 Hours"
        case .hours5:     return "5 Hours"
        case .indefinite: return "Indefinitely"
        }
    }
}
