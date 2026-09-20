import Foundation

// Matches the app Date.dateString() locale, calendar, and time zone defaults.
func serviceDateString(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
}
