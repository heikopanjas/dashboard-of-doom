import Foundation

/// The usual range: a flat line at the median, with the band between the quantiles of the history. For a quantity that stays where it
/// is and only jumps briefly, such as the dose rate, which rain washes up for an hour or two: the spikes widen the band upwards without
/// pulling the line along, and the band stays as wide at every horizon, because the process does not wander.
public struct BaselineModel: ForecastModel {
    /// The last values it looks at, or all of them.
    public let window: Int?

    public init(window: Int? = nil) {
        self.window = window
    }

    public var name: String {
        return "usual range"
    }

    public var minimumHistory: Int {
        return 3
    }

    public func predict(_ values: [Double], horizon: Int, coverage: Double) throws -> [ForecastInterval] {
        guard values.count >= self.minimumHistory else { throw ForecastError.insufficientData }
        let recent = self.window.map { Array(values.suffix(max($0, self.minimumHistory))) } ?? values
        let tail = (1 - min(max(coverage, 0), 1)) / 2
        let interval = ForecastInterval(
            mean: Statistics.median(recent), lower: Statistics.quantile(recent, tail), upper: Statistics.quantile(recent, 1 - tail))
        return [ForecastInterval](repeating: interval, count: max(horizon, 1))
    }
}
