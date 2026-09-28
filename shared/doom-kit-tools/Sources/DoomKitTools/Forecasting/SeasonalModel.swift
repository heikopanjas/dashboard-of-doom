import Foundation

/// A pattern that repeats every `period` steps on top of a damped trend, such as the weekly rhythm of reported cases: fewer at weekends,
/// the backlog on Monday. The pattern comes from the values minus their centred moving average, averaged per phase; the rest goes to the
/// damped trend, and the pattern is added back to its forecast. In a logarithmic scale the pattern is a factor rather than an amount.
public struct SeasonalModel: ForecastModel {
    public let period: Int
    public let base: DampedTrendModel

    public init(period: Int, base: DampedTrendModel = DampedTrendModel()) {
        self.period = max(period, 2)
        self.base = base
    }

    public var name: String {
        return self.period == 7 ? "weekly pattern" : "seasonal pattern"
    }

    public var minimumHistory: Int {
        return 2 * self.period + 1
    }

    public func predict(_ values: [Double], horizon: Int, coverage: Double) throws -> [ForecastInterval] {
        guard values.count >= self.minimumHistory else { throw ForecastError.insufficientData }
        let pattern = self.pattern(values)
        let adjusted = values.enumerated().map { index, value in value - pattern[index % self.period] }
        let intervals = try self.base.predict(adjusted, horizon: horizon, coverage: coverage)
        return intervals.enumerated().map { offset, interval in
            let season = pattern[(values.count + offset) % self.period]
            return ForecastInterval(mean: interval.mean + season, lower: interval.lower + season, upper: interval.upper + season)
        }
    }

    /// The average deviation from the centred moving average in each phase, indexed by position in the series modulo the period, shifted
    /// to sum to zero so it moves nothing on average.
    func pattern(_ values: [Double]) -> [Double] {
        let trend = Self.centredMovingAverage(values, period: self.period)
        var sums = [Double](repeating: 0, count: self.period)
        var counts = [Int](repeating: 0, count: self.period)
        for (index, value) in values.enumerated() {
            guard let average = trend[index] else { continue }
            sums[index % self.period] += value - average
            counts[index % self.period] += 1
        }
        let raw = zip(sums, counts).map { $1 > 0 ? $0 / Double($1) : 0 }
        let mean = raw.reduce(0, +) / Double(self.period)
        return raw.map { $0 - mean }
    }

    /// The average over one full period centred on each value, nil near the ends. An even period averages two neighbouring windows, so
    /// the centre falls on a value rather than between two.
    static func centredMovingAverage(_ values: [Double], period: Int) -> [Double?] {
        var result = [Double?](repeating: nil, count: values.count)
        let half = period / 2
        guard values.count > period else { return result }
        for index in half ..< (values.count - half) {
            if period % 2 == 1 {
                result[index] = values[(index - half) ... (index + half)].reduce(0, +) / Double(period)
            }
            else if index + half < values.count {
                let window = values[(index - half) ... (index + half)]
                let edges = (window.first ?? 0) + (window.last ?? 0)
                result[index] = (window.reduce(0, +) - edges / 2) / Double(period)
            }
        }
        return result
    }
}
