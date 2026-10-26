import Foundation

/// The last value carries on, and the band widens with the square root of the horizon. The honest forecast for a price: whatever the
/// market expected is already in it. With `drift` the average step continues as well.
public struct RandomWalkModel: ForecastModel {
    public let drift: Bool

    public init(drift: Bool = false) {
        self.drift = drift
    }

    public var name: String {
        return "last value"
    }

    public var minimumHistory: Int {
        return 3
    }

    public func predict(_ values: [Double], horizon: Int, coverage: Double) throws -> [ForecastInterval] {
        guard values.count >= self.minimumHistory, let last = values.last else { throw ForecastError.insufficientData }
        let steps = zip(values.dropFirst(), values).map { $0 - $1 }
        let slope = self.drift ? steps.reduce(0, +) / Double(steps.count) : 0
        let spread = Statistics.robustSpread(steps)
        let z = Statistics.z(coverage: coverage)
        return (1 ... max(horizon, 1)).map { h in
            let mean = last + Double(h) * slope
            let half = z * spread * sqrt(Double(h))
            return ForecastInterval(mean: mean, lower: mean - half, upper: mean + half)
        }
    }
}
