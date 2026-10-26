import Foundation

/// How a model did on the series it is meant for, against simply repeating the last value.
public struct BacktestResult: Sendable, Equatable {
    /// The mean absolute error of the model.
    public let mae: Double
    /// The mean absolute error of repeating the last known value.
    public let naiveMAE: Double
    /// The share of held-back values inside the model's band.
    public let coverage: Double
    /// How many held-back values were compared.
    public let count: Int

    /// Below 1 the model beats repeating the last value; above 1 it does worse and should not be shown.
    public var mase: Double {
        guard self.naiveMAE > 0 else { return self.mae > 0 ? .infinity : 1 }
        return self.mae / self.naiveMAE
    }
}

public enum Backtest {
    /// Rolling origins: the series is cut `origins` times, one horizon apart from the end, the model is fitted on what comes before each
    /// cut and compared with the `horizon` values after it. Several cuts give a steadier answer than one. Nil when the series is too short
    /// for even one cut.
    public static func evaluate(
        _ values: [Double], model: some ForecastModel, horizon: Int, origins: Int, coverage: Double = 0.8
    ) -> BacktestResult? {
        var errors: [Double] = []
        var naive: [Double] = []
        var inside = 0
        for k in 1 ... max(origins, 1) {
            let cut = values.count - k * horizon
            guard cut >= model.minimumHistory, horizon > 0 else { break }
            let history = Array(values[..<cut])
            let actual = values[cut ..< (cut + horizon)]
            guard let predicted = try? model.predict(history, horizon: horizon, coverage: coverage), let last = history.last else { continue }
            for (interval, value) in zip(predicted, actual) {
                errors.append(abs(value - interval.mean))
                naive.append(abs(value - last))
                if value >= interval.lower && value <= interval.upper { inside += 1 }
            }
        }
        guard errors.isEmpty == false else { return nil }
        let count = Double(errors.count)
        return BacktestResult(
            mae: errors.reduce(0, +) / count, naiveMAE: naive.reduce(0, +) / count, coverage: Double(inside) / count, count: errors.count)
    }
}
