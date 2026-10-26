import Foundation

public struct TimeSeriesPoint {
    public let timestamp: Date
    public let value: Double
    public init(timestamp: Date, value: Double) {
        self.timestamp = timestamp
        self.value = value
    }
}
