import DoomKitProcess
import Foundation

/// What the charts need to show a forecast, kept apart from the chart marks so it can be tested without Charts.
enum ForecastDisplay {
    /// The drag marker's label: whose forecast a point is, so the app's own estimate is never mistaken for the provider's.
    static func label(for origin: ProcessForecast.Origin) -> String {
        switch origin {
            case .provider(let name):
                return "Forecast · \(name)"
            case .estimate(let method):
                return "Estimate · \(method)"
        }
    }

    /// The footnote under the Show Forecasts switch on both platforms. It says what the switch does to the data as well as to the charts.
    static let settingsExplanation =
        "Continues a source's chart past now with a line, where the source publishes a forecast of its own, such as UBA's for particulate matter. The weather forecast is not affected. Off, forecasts are neither downloaded nor shown."

    /// The legend in a chart's title row, next to a line swatch.
    static func legend(for origin: ProcessForecast.Origin) -> String {
        switch origin {
            case .provider(let name):
                return "\(name) forecast"
            case .estimate(let method):
                return "App estimate (\(method))"
        }
    }

    /// The chart's y range grown to hold the forecast and its band. Every chart pins its y scale to the measured range, which would clip
    /// a forecast that leaves it.
    static func domain(range: ClosedRange<Double>?, forecast: ProcessForecast?) -> ClosedRange<Double> {
        let range = range ?? 0.0 ... 0.0
        guard let forecast, forecast.points.isEmpty == false else { return range }
        let values = forecast.points.flatMap { [$0.value.value, $0.lower, $0.upper].compactMap { $0 } }
        return min(range.lowerBound, values.min() ?? range.lowerBound) ... max(range.upperBound, values.max() ?? range.upperBound)
    }

    /// The forecast point a drag marker at `timestamp` shows: the nearest point within half the forecast's spacing. The drag rounds to
    /// the chart's own grid, a quarter hour or a day, which a provider's forecast does not have to share.
    static func point(at timestamp: Date, in forecast: ProcessForecast?) -> ProcessForecast.Point? {
        guard let forecast else { return nil }
        return forecast.point(near: timestamp, tolerance: Self.tolerance(for: forecast))
    }

    /// Half the median spacing of the points, an hour for a forecast of a single point.
    static func tolerance(for forecast: ProcessForecast) -> TimeInterval {
        let timestamps = forecast.points.map(\.timestamp)
        let gaps = zip(timestamps.dropFirst(), timestamps).map { $0.timeIntervalSince($1) }.sorted()
        guard gaps.isEmpty == false else { return 3600 }
        return max(gaps[gaps.count / 2] / 2, 60)
    }
}
