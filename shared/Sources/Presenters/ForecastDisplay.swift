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

    /// The footnote under a source's Show Forecast switch, on both platforms. It says whose forecast the line is, how far it reaches,
    /// whether it can warn, and what off does to the data as well as to the chart.
    static func settingsExplanation(for family: ForecastFamily) -> String {
        let off = "Off, nothing is downloaded or estimated for it."
        switch family {
            case .level:
                return "Continues each gauge's chart past now: PEGELONLINE's forecast for the gauges on the Elbe, Rhine, Oder, Danube and Saale that have one, which also warns before a flood mark is reached, and elsewhere the app's own estimate, the tide on tidal gauges for a day and the trend for 12 hours. \(off)"
            case .radiation:
                return "Continues the dose rate past now with the app's own estimate: the range it usually stays in, for a day. BfS publishes no forecast. \(off)"
            case .particles:
                return "Continues each pollutant past now with UBA's forecast, about three days ahead, which also warns before a limit is reached. \(off)"
            case .covid:
                return "Continues the district's figures past now with the app's own estimate for two weeks: the weekly reporting pattern for daily counts, the trend for the incidence. No one publishes a forecast. \(off)"
            case .energy:
                return "Continues each price past now with the app's own estimate for 30 days: the last price, with the range a year of daily moves allows. No free forecast exists. \(off)"
            case .polls:
                return "Continues each party's share past now with the app's own estimate: its trend in weekly averages of the polls, for 13 weeks. DAWUM publishes no projection. \(off)"
        }
    }

    /// The legend in a chart's title row, next to a line swatch.
    static func legend(for origin: ProcessForecast.Origin) -> String {
        switch origin {
            case .provider(let name):
                return "\(name) forecast"
            case .estimate(let method):
                return "App estimate (\(method))"
        }
    }

    /// The legend where the full one does not fit beside the title.
    static func shortLegend(for origin: ProcessForecast.Origin) -> String {
        switch origin {
            case .provider(let name):
                return name
            case .estimate:
                return "Estimate"
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
