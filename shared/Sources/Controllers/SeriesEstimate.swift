import DoomKitProcess
import DoomKitTools
import Foundation

/// The app's own estimate of where a series goes next, for sources that publish no forecast. It is always labelled as an estimate with
/// its method, never as the provider's, and never raises a warning.
enum SeriesEstimate {
    /// The estimate of `raw`, the series as parsed: never the gap-filled one, whose carried values would make it look flatter than it
    /// was. Nil when the series is too short, when its last value is older than `maximumAge` (a feed that stopped is not continued), or
    /// when the model fails.
    ///
    /// Before it is used, `model` is backtested on the series itself against repeating the last value; if it does worse, the last value
    /// with a widening band is what is shown, and the label says so.
    static func make(
        from raw: [ProcessValue<Dimension>], model: some ForecastModel, request: ForecastRequest, maximumAge: TimeInterval, now: Date = .now
    ) -> ProcessForecast? {
        let usable = raw.filter { $0.quality != .unknown && $0.quality != .bad }.sorted { $0.timestamp < $1.timestamp }
        guard let first = usable.first, let last = usable.last, now.timeIntervalSince(last.timestamp) <= maximumAge else { return nil }
        let unit = first.value.unit
        let points = usable.map { TimeSeriesPoint(timestamp: $0.timestamp, value: $0.value.converted(to: unit).value) }
        let chosen: any ForecastModel = Self.beatsTheLastValue(model, points: points, request: request) ? model : RandomWalkModel()
        guard let predicted = try? Forecaster.forecast(points, model: chosen, request: request), predicted.isEmpty == false else { return nil }
        return ProcessForecast(
            origin: .estimate(chosen.name),
            points: predicted.map { point in
                ProcessForecast.Point(
                    timestamp: point.timestamp, value: Measurement(value: point.value, unit: unit), lower: point.lower, upper: point.upper)
            })
    }

    /// Whether `model` beats repeating the last value on the series' own recent past, three horizons back where the history allows. A
    /// series too short to tell keeps the model.
    static func beatsTheLastValue(_ model: some ForecastModel, points: [TimeSeriesPoint], request: ForecastRequest) -> Bool {
        guard let values = try? Forecaster.prepare(points, request: request).values else { return true }
        let horizon = min(request.horizon, max((values.count - model.minimumHistory) / 3, 1))
        guard let result = Backtest.evaluate(values, model: model, horizon: horizon, origins: 3, coverage: request.coverage) else { return true }
        return result.mase <= 1
    }
}
