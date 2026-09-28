import Foundation

/// Runs a model on a measured series: puts the history on an even grid, transforms it, predicts, and turns the prediction back into dated
/// values in the series' own scale, inside its bounds.
public enum Forecaster {
    public static func forecast(_ points: [TimeSeriesPoint], model: some ForecastModel, request: ForecastRequest) throws -> [ForecastPoint] {
        let (values, last) = try Self.prepare(points, request: request)
        guard values.count >= max(model.minimumHistory, 2), request.horizon > 0 else { throw ForecastError.insufficientData }
        let intervals = try model.predict(values, horizon: request.horizon, coverage: request.coverage)
        return intervals.enumerated().map { index, interval in
            var value = request.transform.backward(interval.mean)
            var lower = request.transform.backward(interval.lower)
            var upper = request.transform.backward(interval.upper)
            if let bounds = request.bounds {
                value = min(max(value, bounds.lowerBound), bounds.upperBound)
                lower = min(max(lower, bounds.lowerBound), bounds.upperBound)
                upper = min(max(upper, bounds.lowerBound), bounds.upperBound)
            }
            return ForecastPoint(
                timestamp: last.addingTimeInterval(Double(index + 1) * request.step), value: value, lower: min(lower, value), upper: max(upper, value))
        }
    }

    /// The history as a model sees it: on the grid, transformed, oldest first, with the time of its last value, which the forecast
    /// continues from. Also what a backtest of the same request runs on.
    public static func prepare(_ points: [TimeSeriesPoint], request: ForecastRequest) throws -> (values: [Double], last: Date) {
        let grid = TimeSeriesGrid.regularize(points, step: request.step, maximumGap: request.maximumGap)
        guard let last = grid.last?.timestamp else { throw ForecastError.insufficientData }
        let values = grid.map { request.transform.forward($0.value) }
        guard values.allSatisfy({ $0.isFinite }) else { throw ForecastError.nonFinite }
        return (values, last)
    }
}

public enum TimeSeriesGrid {
    /// The series at every `step` back from its last point, interpolated linearly between the points around each grid time. Linear rather
    /// than carrying the last value forward: a carried value makes the series look flatter than it was, and a model fitted to it would
    /// draw too narrow a band. Only what follows the last gap longer than `maximumGap` is kept.
    public static func regularize(_ points: [TimeSeriesPoint], step: TimeInterval, maximumGap: TimeInterval? = nil) -> [TimeSeriesPoint] {
        var sorted: [TimeSeriesPoint] = []
        for point in points.filter({ $0.value.isFinite }).sorted(by: { $0.timestamp < $1.timestamp }) {
            // Of two values at the same time, the later one in the input wins.
            if sorted.last?.timestamp == point.timestamp { sorted.removeLast() }
            sorted.append(point)
        }
        if let maximumGap, let gap = sorted.indices.dropFirst().last(where: { sorted[$0].timestamp.timeIntervalSince(sorted[$0 - 1].timestamp) > maximumGap }) {
            sorted = Array(sorted[gap...])
        }
        guard let first = sorted.first, let last = sorted.last, step > 0 else { return [] }
        let count = Int((last.timestamp.timeIntervalSince(first.timestamp) / step).rounded(.down))
        var grid: [TimeSeriesPoint] = []
        grid.reserveCapacity(count + 1)
        var index = 0
        for k in stride(from: count, through: 0, by: -1) {
            let time = last.timestamp.addingTimeInterval(-Double(k) * step)
            while index + 1 < sorted.count && sorted[index + 1].timestamp <= time { index += 1 }
            let before = sorted[index]
            let value: Double
            if before.timestamp == time || index + 1 >= sorted.count {
                value = before.value
            }
            else {
                let after = sorted[index + 1]
                let share = time.timeIntervalSince(before.timestamp) / after.timestamp.timeIntervalSince(before.timestamp)
                value = before.value + share * (after.value - before.value)
            }
            grid.append(TimeSeriesPoint(timestamp: time, value: value))
        }
        return grid
    }
}

enum Statistics {
    /// The standard normal quantile, by Acklam's rational approximation, good to about 1e-9.
    static func normalQuantile(_ p: Double) -> Double {
        let a = [-3.969683028665376e+01, 2.209460984245205e+02, -2.759285104469687e+02, 1.383577518672690e+02, -3.066479806614716e+01, 2.506628277459239e+00]
        let b = [-5.447609879822406e+01, 1.615858368580409e+02, -1.556989798598866e+02, 6.680131188771972e+01, -1.328068155288572e+01]
        let c = [-7.784894002430293e-03, -3.223964580411365e-01, -2.400758277161838e+00, -2.549732539343734e+00, 4.374664141464968e+00, 2.938163982698783e+00]
        let d = [7.784695709041462e-03, 3.224671290700398e-01, 2.445134137142996e+00, 3.754408661907416e+00]
        let p = min(max(p, 1e-12), 1 - 1e-12)
        let low = 0.02425
        if p < low {
            let q = sqrt(-2 * log(p))
            return (((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) / ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1)
        }
        if p > 1 - low {
            let q = sqrt(-2 * log(1 - p))
            return -(((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) / ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1)
        }
        let q = p - 0.5
        let r = q * q
        return (((((a[0] * r + a[1]) * r + a[2]) * r + a[3]) * r + a[4]) * r + a[5]) * q
            / (((((b[0] * r + b[1]) * r + b[2]) * r + b[3]) * r + b[4]) * r + 1)
    }

    /// The z of a central band holding `coverage`: 1.28 for 80 %.
    static func z(coverage: Double) -> Double {
        return Self.normalQuantile(0.5 + min(max(coverage, 0), 0.999_999) / 2)
    }

    /// The `p` quantile, interpolated between the order statistics.
    static func quantile(_ values: [Double], _ p: Double) -> Double {
        let sorted = values.sorted()
        guard sorted.isEmpty == false else { return .nan }
        let position = min(max(p, 0), 1) * Double(sorted.count - 1)
        let lower = Int(position.rounded(.down))
        let upper = min(lower + 1, sorted.count - 1)
        return sorted[lower] + (position - Double(lower)) * (sorted[upper] - sorted[lower])
    }

    static func median(_ values: [Double]) -> Double {
        return Self.quantile(values, 0.5)
    }

    /// A spread that a few wild values do not inflate: the median absolute deviation, scaled to match the standard deviation of normally
    /// distributed values. Falls back to the standard deviation when more than half the values are equal.
    static func robustSpread(_ values: [Double]) -> Double {
        let center = Self.median(values)
        let mad = 1.4826 * Self.median(values.map { abs($0 - center) })
        if mad > 0 { return mad }
        let mean = values.reduce(0, +) / Double(max(values.count, 1))
        return sqrt(values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(max(values.count - 1, 1)))
    }
}
