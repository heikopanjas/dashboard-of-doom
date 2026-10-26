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

    /// The months a monthly series has not reported yet, up to today, for sources that arrive months late (fuel stocks, oil production),
    /// whose charts would otherwise stop well short of now. A damped trend on a monthly grid, kept within `bounds`, which falls back to the
    /// last value where that did better on the series' own past; a month at a time from the last report, with the last point today. Not
    /// continued when the last report is more than half a year old.
    static func monthly(from values: [ProcessValue<Dimension>], bounds: ClosedRange<Double>, now: Date = .now) -> ProcessForecast? {
        guard let last = values.last, now > last.timestamp else { return nil }
        let month = 365.25 / 12 * 24 * 3600
        let horizon = Int((now.timeIntervalSince(last.timestamp) / month).rounded(.up))
        guard
            let forecast = Self.make(
                from: values, model: DampedTrendModel(),
                request: ForecastRequest(step: month, horizon: horizon, bounds: bounds, maximumGap: 3 * month),
                maximumAge: 183 * 24 * 3600, now: now)
        else { return nil }
        return Self.ending(forecast, at: now, from: last)
    }

    /// The forecast cut at `date`: the points before it, then one at `date` between its neighbours, the last measurement standing in for
    /// the first point's predecessor. Nothing when no point reaches `date`.
    static func ending(_ forecast: ProcessForecast, at date: Date, from last: ProcessValue<Dimension>) -> ProcessForecast? {
        guard let next = forecast.points.first(where: { $0.timestamp >= date }) else { return nil }
        let before = forecast.points.filter { $0.timestamp < date }
        let unit = next.value.unit
        let previous =
            before.last
            ?? ProcessForecast.Point(timestamp: last.timestamp, value: last.value.converted(to: unit), lower: nil, upper: nil)
        let span = next.timestamp.timeIntervalSince(previous.timestamp)
        let share = span > 0 ? date.timeIntervalSince(previous.timestamp) / span : 1
        let between = { (from: Double, to: Double) in return from + (to - from) * share }
        let value = between(previous.value.value, next.value.value)
        var lower: Double?
        var upper: Double?
        if let nextLower = next.lower, let nextUpper = next.upper {
            lower = between(previous.lower ?? previous.value.value, nextLower)
            upper = between(previous.upper ?? previous.value.value, nextUpper)
        }
        let end = ProcessForecast.Point(timestamp: date, value: Measurement(value: value, unit: unit), lower: lower, upper: upper)
        return ProcessForecast(origin: forecast.origin, issued: forecast.issued, points: before + [end], customData: forecast.customData)
    }
}
