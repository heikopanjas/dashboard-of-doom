import Foundation

/// Tides: sine waves of known periods, fitted by least squares, on top of a damped trend. The periods need not be whole steps, which a
/// seasonal index would need: the principal lunar tide M2 lasts 12.42 hours, 49.68 quarter hours, and its overtide M4 half that. Three
/// days of history cannot tell M2 from the solar S2, so the two together are the shape the model follows.
public struct HarmonicModel: ForecastModel {
    /// The M2 tide and its M4 overtide, in hours.
    public static let tidalPeriods: [Double] = [12.4206, 6.2103]

    /// Periods in steps of the series.
    public let periods: [Double]
    public let base: DampedTrendModel

    public init(periods: [Double], base: DampedTrendModel = DampedTrendModel()) {
        self.periods = periods.filter { $0 > 1 }
        self.base = base
    }

    public var name: String {
        return "tide"
    }

    public var minimumHistory: Int {
        return Int((2 * (self.periods.max() ?? 1)).rounded(.up))
    }

    public func predict(_ values: [Double], horizon: Int, coverage: Double) throws -> [ForecastInterval] {
        guard values.count >= self.minimumHistory, self.periods.isEmpty == false else { throw ForecastError.insufficientData }
        guard let fit = Self.regression(values, periods: self.periods) else { throw ForecastError.insufficientData }
        let adjusted = values.enumerated().map { index, value in value - fit.waves(at: Double(index)) }
        let intervals = try self.base.predict(adjusted, horizon: horizon, coverage: coverage)
        return intervals.enumerated().map { offset, interval in
            let wave = fit.waves(at: Double(values.count + offset))
            return ForecastInterval(mean: interval.mean + wave, lower: interval.lower + wave, upper: interval.upper + wave)
        }
    }

    /// Whether the waves explain at least `minimumR2` of what a straight line leaves over, which is how a tidal gauge is told from a river
    /// or a canal without a list of gauges.
    public static func detect(_ values: [Double], periods: [Double], minimumR2: Double = 0.5) -> Bool {
        guard let waves = Self.regression(values, periods: periods), let line = Self.regression(values, periods: []), line.residual > 0 else {
            return false
        }
        return 1 - waves.residual / line.residual >= minimumR2
    }

    struct Regression {
        let periods: [Double]
        /// Constant, slope, then a sine and a cosine per period.
        let coefficients: [Double]
        let residual: Double

        func waves(at t: Double) -> Double {
            var sum = 0.0
            for (index, period) in self.periods.enumerated() {
                let angle = 2 * Double.pi * t / period
                sum += self.coefficients[2 + 2 * index] * sin(angle) + self.coefficients[3 + 2 * index] * cos(angle)
            }
            return sum
        }
    }

    /// Least squares for a constant, a slope and the waves, by the normal equations. The slope keeps a rising or falling water level from
    /// being read as part of a wave.
    static func regression(_ values: [Double], periods: [Double]) -> Regression? {
        let count = values.count
        let unknowns = 2 + 2 * periods.count
        guard count > unknowns else { return nil }
        func row(_ t: Double) -> [Double] {
            var row = [1, t / Double(count)]
            for period in periods {
                let angle = 2 * Double.pi * t / period
                row.append(sin(angle))
                row.append(cos(angle))
            }
            return row
        }
        var matrix = [[Double]](repeating: [Double](repeating: 0, count: unknowns), count: unknowns)
        var vector = [Double](repeating: 0, count: unknowns)
        for (index, value) in values.enumerated() {
            let r = row(Double(index))
            for i in 0 ..< unknowns {
                vector[i] += r[i] * value
                for j in 0 ..< unknowns { matrix[i][j] += r[i] * r[j] }
            }
        }
        guard let coefficients = Self.solve(matrix, vector) else { return nil }
        let residual = values.enumerated().reduce(0.0) { sum, item in
            let r = row(Double(item.offset))
            let fitted = zip(r, coefficients).reduce(0) { $0 + $1.0 * $1.1 }
            return sum + (item.element - fitted) * (item.element - fitted)
        }
        return Regression(periods: periods, coefficients: coefficients, residual: residual)
    }

    /// Gaussian elimination with partial pivoting; nil for a singular system.
    static func solve(_ matrix: [[Double]], _ vector: [Double]) -> [Double]? {
        var a = matrix
        var b = vector
        let n = b.count
        for column in 0 ..< n {
            guard let pivot = (column ..< n).max(by: { abs(a[$0][column]) < abs(a[$1][column]) }), abs(a[pivot][column]) > 1e-12 else {
                return nil
            }
            a.swapAt(column, pivot)
            b.swapAt(column, pivot)
            for rowIndex in (column + 1) ..< n {
                let factor = a[rowIndex][column] / a[column][column]
                for k in column ..< n { a[rowIndex][k] -= factor * a[column][k] }
                b[rowIndex] -= factor * b[column]
            }
        }
        var x = [Double](repeating: 0, count: n)
        for rowIndex in stride(from: n - 1, through: 0, by: -1) {
            let sum = ((rowIndex + 1) ..< n).reduce(0.0) { $0 + a[rowIndex][$1] * x[$1] }
            x[rowIndex] = (b[rowIndex] - sum) / a[rowIndex][rowIndex]
        }
        return x
    }
}
