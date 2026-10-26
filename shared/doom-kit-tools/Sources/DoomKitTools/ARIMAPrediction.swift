import Foundation

public struct ARIMAPrediction {
    public let forecasts: [TimeSeriesPoint]
    public let confidenceIntervals: [(lower: Double, upper: Double)]
}
