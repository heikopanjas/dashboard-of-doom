import Foundation

public enum TimeSeriesInterval {
    case quarterHourly
    case hourly
    case daily
    case custom(TimeInterval)

    public var interval: TimeInterval {
        switch self {
            case .quarterHourly: return 15 * 60  // 15 minutes
            case .hourly: return 3600  // 1 hour
            case .daily: return 24 * 3600  // 24 hours
            case .custom(let interval): return interval
        }
    }
}
