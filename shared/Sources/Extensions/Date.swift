import Foundation

enum RoundingStrategy {
    case previousQuarterHour
    case nextQuarterHour
    case previousHour
    case nextHour
    case lastDayChange
    case lastUTCDayChange
}

extension Date {
    static func diff(from: Date, to: Date) -> Int? {
        var delta: Int?
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: from, to: to)
        if let days = components.day {
            delta = abs(days)
        }
        return delta
    }

    static func round(from: Date, strategy: RoundingStrategy) -> Date? {
        switch strategy {
            case .previousQuarterHour:
                return roundToPreviousQuarterHour(from: from)
            case .nextQuarterHour:
                return roundToNextQuarterHour(from: from)
            case .previousHour:
                return roundToPreviousHour(from: from)
            case .nextHour:
                return roundToNextHour(from: from)
            case .lastDayChange:
                return roundToLastDayChange(from: from)
            case .lastUTCDayChange:
                return roundToLastUTCDayChange(from: from)
        }
    }

    private static func roundToPreviousQuarterHour(from: Date) -> Date? {
        let calendar = Calendar.current

        // Extract hour, minute, and second components from the input date
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: from)

        guard let minute = components.minute else { return nil }

        // Calculate the remainder when dividing minutes by 15
        let remainder = minute % 15

        // Adjust to the previous quarter hour
        var adjustedComponents = components
        adjustedComponents.minute = minute - remainder
        adjustedComponents.second = 0  // Set seconds to 0 for clean rounding

        // Create a new date using the adjusted components
        return calendar.date(from: adjustedComponents)
    }

    private static func roundToPreviousHour(from: Date) -> Date? {
        let calendar = Calendar.current

        // Extract year, month, day, hour components from the input date
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: from)

        guard let hour = components.hour else { return nil }

        // Adjust to the previous hour
        var adjustedComponents = components
        adjustedComponents.hour = hour
        adjustedComponents.minute = 0  // Reset minutes to 0
        adjustedComponents.second = 0  // Reset seconds to 0

        // Create a new date using the adjusted components
        return calendar.date(from: adjustedComponents)
    }

    private static func roundToLastDayChange(from: Date) -> Date? {
        let calendar = Calendar.current

        // Extract year, month, day, hour components from the input date
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: from)

        // Adjust to the previous hour
        var adjustedComponents = components
        adjustedComponents.hour = 0  // Reset hours to 0
        adjustedComponents.minute = 0  // Reset minutes to 0
        adjustedComponents.second = 0  // Reset seconds to 0
        adjustedComponents.timeZone = TimeZone(abbreviation: "UTC")

        // Create a new date using the adjusted components
        return calendar.date(from: adjustedComponents)
    }

    private static func roundToLastUTCDayChange(from: Date) -> Date? {
        let calendar = Calendar.current

        // Extract year, month, day, hour components from the input date
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: from)

        // Adjust to the previous hour
        var adjustedComponents = components
        adjustedComponents.hour = 0  // Reset hours to 0
        adjustedComponents.minute = 0  // Reset minutes to 0
        adjustedComponents.second = 0  // Reset seconds to 0
        adjustedComponents.timeZone = TimeZone(abbreviation: "UTC")

        // Create a new date using the adjusted components
        return calendar.date(from: adjustedComponents)
    }

    private static func roundToNextQuarterHour(from date: Date) -> Date? {
        // Get the current calendar
        let calendar = Calendar.current

        // Extract hour, minute, and other components from the date
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)

        // Calculate the next quarter hour
        if let minute = components.minute {
            let remainder = minute % 15
            let minutesToAdd = 15 - remainder

            // Add the minutes to reach the next quarter
            components.minute = minute + minutesToAdd
            components.second = 0  // Reset seconds to zero

            if let minutes = components.minute {
                if minutes >= 60 {
                    components.minute = minutes - 60
                    components.hour = (components.hour ?? 0) + 1
                    if components.hour == 24 {
                        // Adjust for day rollover
                        components.hour = 0
                        if let nextDay = calendar.date(byAdding: .day, value: 1, to: date) {
                            components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: nextDay)
                        }
                    }
                }
            }
            else {
                return nil
            }
        }

        // Create the next quarter-hour date
        return calendar.date(from: components)
    }

    private static func roundToNextHour(from date: Date) -> Date? {
        // Get the current calendar
        let calendar = Calendar.current

        // Extract hour and other components from the date
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)

        // Increment the hour
        components.hour = (components.hour ?? 0) + 1
        components.minute = 0  // Reset minutes to zero
        components.second = 0  // Reset seconds to zero

        // Handle day rollover
        if components.hour == 24 {
            components.hour = 0
            if let nextDay = calendar.date(byAdding: .day, value: 1, to: date) {
                let nextComponents = calendar.dateComponents([.year, .month, .day], from: nextDay)
                components.year = nextComponents.year
                components.month = nextComponents.month
                components.day = nextComponents.day
            }
        }

        // Create the next hour date
        return calendar.date(from: components)
    }

    private func absoluteString(fmtStr: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = fmtStr
        return String(format: "%@", formatter.string(from: self))
    }

    func relativeString() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return String(format: "%@", formatter.string(for: self) ?? "<Unknown>")
    }

    func absoluteString() -> String {
        return self.absoluteString(fmtStr: "yyyy-MM-dd HH:mm")
    }

    static func absoluteString(date: Date?) -> String {
        guard let date else { return "<Unknown>" }
        return date.absoluteString()
    }

    func string() -> String {
        return self.absoluteString(fmtStr: "yyyy-MM-dd HH:mm")
    }

    func timeString() -> String {
        return self.absoluteString(fmtStr: "HH:mm")
    }

    func dateString() -> String {
        return self.absoluteString(fmtStr: "yyyy-MM-dd")
    }

    static func fromString(_ string: String, format: String) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = format
        return dateFormatter.date(from: string)
    }
}
