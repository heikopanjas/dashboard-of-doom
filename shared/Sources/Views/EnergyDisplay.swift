import DoomKitProcess
import Foundation

/// What the Energy tab's charts print, and which value a dragged marker lands on; both platforms' chart views use it.
enum EnergyDisplay {
    static func title(for selector: ProcessSelector) -> String {
        guard case .energy(let energy) = selector else { return "<Unknown>" }
        switch energy {
            case .brentSpot:
                return "Brent Spot"
            case .brent:
                return "Brent Futures"
            case .ttf:
                return "TTF Futures"
            case .lng:
                return "LNG Spot"
            case .petrolStock:
                return "Petrol"
            case .dieselStock:
                return "Diesel"
            case .jetFuelStock:
                return "Jet Fuel"
            case .production:
                return "Production"
        }
    }

    /// Days of supply to one decimal; prices to the cent, and production to ten thousand barrels a day.
    static func format(for selector: ProcessSelector) -> String {
        return Self.isStock(selector) == true ? "%.1f %@" : "%.2f %@"
    }

    static func valueText(_ value: ProcessValue<Dimension>, for selector: ProcessSelector) -> String {
        return String(format: Self.format(for: selector), value.value.value, value.value.unit.symbol)
    }

    /// The minimum days of supply EuroOilWatch holds a stock against, from the latest month that names one. Nothing for a price, or when
    /// the latest month could not be fetched.
    static func minimumDays(in values: [ProcessValue<Dimension>]) -> Double? {
        return values.last(where: { $0.customData?["mandatoryMinimumDays"] != nil })?.customData?["mandatoryMinimumDays"] as? Double
    }

    /// EuroOilWatch's assessment of a stock, `critical`, `warning`, `watch`, `safe` or `unassessed`, from the latest month that has one.
    static func status(in values: [ProcessValue<Dimension>]) -> String? {
        return values.last(where: { $0.customData?["status"] != nil })?.customData?["status"] as? String
    }

    /// The month the status belongs to, which can be older than the latest month charted: the two endpoints do not end alike.
    static func statusPeriod(in values: [ProcessValue<Dimension>]) -> String? {
        return values.last(where: { $0.customData?["status"] != nil })?.customData?["period"] as? String
    }

    /// A monthly series, a stock or production, is labelled with its month; a price with its day.
    static func dateText(_ date: Date, for selector: ProcessSelector) -> String {
        if Self.isMonthly(selector) == true {
            return date.formatted(.dateTime.month(.abbreviated).year())
        }
        return date.dateString()
    }

    /// The measurement a dragged marker shows: the one nearest the dragged date, while the date lies within half a step of the series,
    /// the series' usual spacing. Daily prices then behave as before, landing on their own day, while a monthly stock is found from any
    /// day of its month. Past the last half step there is nothing, so the marker can fall back to the forecast.
    static func measurement(at date: Date, in values: [ProcessValue<Dimension>]) -> ProcessValue<Dimension>? {
        guard let first = values.first, let last = values.last else { return nil }
        let halfStep = Self.step(of: values) / 2
        guard date >= first.timestamp.addingTimeInterval(-halfStep), date <= last.timestamp.addingTimeInterval(halfStep) else { return nil }
        return values.min { abs($0.timestamp.timeIntervalSince(date)) < abs($1.timestamp.timeIntervalSince(date)) }
    }

    /// The median spacing of the series, a day when there is only one value.
    private static func step(of values: [ProcessValue<Dimension>]) -> TimeInterval {
        let gaps = zip(values.dropFirst(), values).map { $0.timestamp.timeIntervalSince($1.timestamp) }.sorted()
        if gaps.isEmpty == true {
            return 24 * 3600
        }
        return gaps[gaps.count / 2]
    }

    private static func isStock(_ selector: ProcessSelector) -> Bool {
        guard case .energy(let energy) = selector else { return false }
        return energy.isStock
    }

    private static func isMonthly(_ selector: ProcessSelector) -> Bool {
        guard case .energy(let energy) = selector else { return false }
        return energy.isMonthly
    }
}
