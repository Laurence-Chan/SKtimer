import Foundation

enum TimerDurationFormatter {
    static func compact(minutes: Int) -> String {
        compact(seconds: minutes * 60)
    }

    static func compact(seconds: Int) -> String {
        let totalMinutes = max(0, Int(ceil(Double(seconds) / 60.0)))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }

        if totalMinutes == 0 {
            return "0m"
        }

        return "\(totalMinutes)m"
    }

    static func menuBar(seconds: Int) -> String {
        let totalMinutes = max(0, Int(ceil(Double(seconds) / 60.0)))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return "\(hours)h \(String(format: "%02d", minutes))m"
        }

        if totalMinutes == 0 {
            return "0m"
        }

        return "\(totalMinutes)m"
    }

    static func accessibility(minutes: Int) -> String {
        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        switch (hours, remainingMinutes) {
        case (0, let minutes):
            return "\(minutes) minutes"
        case (let hours, 0):
            return "\(hours) hours"
        default:
            return "\(hours) hours \(remainingMinutes) minutes"
        }
    }
}
