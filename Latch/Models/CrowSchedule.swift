import Foundation

/// A time-of-day window during which Latch auto-activates.
struct CrowSchedule: Codable, Identifiable, Equatable {

    var id: UUID = UUID()
    var name: String = "Work Hours"
    var startHour: Int = 9
    var startMinute: Int = 0
    var endHour: Int = 18
    var endMinute: Int = 0
    /// Calendar weekday integers: 1 = Sunday … 7 = Saturday
    var weekdays: Set<Int> = [2, 3, 4, 5, 6]  // Mon–Fri
    var isEnabled: Bool = true

    // MARK: - Display helpers

    var startTimeString: String { String(format: "%02d:%02d", startHour, startMinute) }
    var endTimeString:   String { String(format: "%02d:%02d", endHour,   endMinute)   }

    static let weekdayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var weekdaysShortString: String {
        (1...7).filter { weekdays.contains($0) }
               .map   { Self.weekdayNames[$0 - 1] }
               .joined(separator: ", ")
    }

    // MARK: - Active check

    /// Returns true if the current moment falls within this schedule window.
    func isCurrentlyActive(using calendar: Calendar = .current) -> Bool {
        guard isEnabled else { return false }
        let comps = calendar.dateComponents([.weekday, .hour, .minute], from: Date())
        guard let weekday = comps.weekday,
              let hour    = comps.hour,
              let minute  = comps.minute else { return false }

        let current = hour * 60 + minute
        let start   = startHour * 60 + startMinute
        let end     = endHour   * 60 + endMinute

        if start <= end {
            // Normal window (e.g. 09:00–18:00)
            return weekdays.contains(weekday) && current >= start && current < end
        }

        // Overnight window (e.g. 22:00–06:00)
        if current >= start {
            // Evening part — belongs to today's weekday
            return weekdays.contains(weekday)
        }
        if current < end {
            // Morning tail — belongs to the weekday the window started on (yesterday)
            let yesterday = weekday == 1 ? 7 : weekday - 1
            return weekdays.contains(yesterday)
        }
        return false
    }
}
