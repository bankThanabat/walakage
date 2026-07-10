import Foundation

enum SessionTimerSelection: String, CaseIterable, Identifiable {
    case off
    case fifteenMinutes
    case thirtyMinutes
    case oneHour
    case twoHours
    case fourHours
    case custom

    var id: Self { self }

    var title: String {
        switch self {
        case .off: "Off"
        case .fifteenMinutes: "15m"
        case .thirtyMinutes: "30m"
        case .oneHour: "1h"
        case .twoHours: "2h"
        case .fourHours: "4h"
        case .custom: "Custom"
        }
    }
}

enum SessionTimer {
    struct Components: Equatable {
        let hours: Int
        let minutes: Int
    }

    static func clamp(hours: Int, minutes: Int) -> Components {
        let hours = min(max(hours, 0), 24)
        let minutes = hours == 24 ? 0 : min(max(minutes, 0), 59)
        return Components(hours: hours, minutes: minutes)
    }

    static func duration(
        for selection: SessionTimerSelection,
        customHours: Int,
        customMinutes: Int
    ) -> TimeInterval? {
        let seconds: Int
        switch selection {
        case .off:
            seconds = 0
        case .fifteenMinutes:
            seconds = 15 * 60
        case .thirtyMinutes:
            seconds = 30 * 60
        case .oneHour:
            seconds = 60 * 60
        case .twoHours:
            seconds = 2 * 60 * 60
        case .fourHours:
            seconds = 4 * 60 * 60
        case .custom:
            let custom = clamp(hours: customHours, minutes: customMinutes)
            seconds = (custom.hours * 60 + custom.minutes) * 60
        }
        return seconds == 0 ? nil : TimeInterval(seconds)
    }

    static func countdown(deadline: Date, now: Date) -> String? {
        let remaining = deadline.timeIntervalSince(now)
        guard remaining > 0 else { return nil }

        let totalMinutes = Int(ceil(remaining / 60))
        guard totalMinutes >= 60 else { return "\(totalMinutes)m left" }

        return String(format: "%dh %02dm left", totalMinutes / 60, totalMinutes % 60)
    }
}
