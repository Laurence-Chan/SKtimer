import Foundation

enum TimerInputError: Error, Equatable {
    case invalidHours
    case invalidMinutes
    case durationTooShort
    case durationTooLong

    var localizedKey: String {
        switch self {
        case .invalidHours:
            "timer.error.invalidHours"
        case .invalidMinutes:
            "timer.error.invalidMinutes"
        case .durationTooShort:
            "timer.error.durationTooShort"
        case .durationTooLong:
            "timer.error.durationTooLong"
        }
    }
}

enum TimerInputValidator {
    static func durationMinutes(hoursText: String, minutesText: String) -> Result<Int, TimerInputError> {
        guard let hours = parseInteger(hoursText), (0...999).contains(hours) else {
            return .failure(.invalidHours)
        }

        guard let minutes = parseInteger(minutesText), (0...59).contains(minutes) else {
            return .failure(.invalidMinutes)
        }

        let totalMinutes = (hours * 60) + minutes

        guard totalMinutes >= TimerRecord.minimumMinutes else {
            return .failure(.durationTooShort)
        }

        guard totalMinutes <= TimerRecord.maximumMinutes else {
            return .failure(.durationTooLong)
        }

        return .success(totalMinutes)
    }

    static func sanitizedDigits(_ value: String, limit: Int) -> String {
        String(value.filter(\.isNumber).prefix(limit))
    }

    private static func parseInteger(_ value: String) -> Int? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            return 0
        }

        guard trimmed.allSatisfy(\.isNumber) else {
            return nil
        }

        return Int(trimmed)
    }
}
