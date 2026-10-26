import DoomKitLocation
import DoomKitNetwork
import DoomKitProcess
import DoomKitServices
import DoomKitTools
import Foundation

/// European energy prices: Brent spot and futures, TTF futures and ACER LNG spot, and Germany's fuel stocks. Prices have no place, so the
/// sensor's location is nominal and never shown, and the source is not on the map.
class EnergyController: ProcessController {
    /// A year of prices: enough to show a trend and the winter and summer swing of gas, and still one point per two or three pixels on
    /// a phone.
    static let span: TimeInterval = 365 * 24 * 60 * 60

    /// The country whose fuel stocks are shown. Germany, whatever the reader's location, like the rest of the app's data.
    static let stockCountry = "DE"

    /// Nominal, never shown: prices have no place. Berlin, since that is where the app looks by default.
    private static let location = Location(latitude: 52.5186, longitude: 13.3763)

    private let networkManager: NetworkManager
    private let showForecasts: @Sendable () -> Bool

    init(
        networkManager: NetworkManager = .shared,
        showForecasts: @escaping @Sendable () -> Bool = { return SourcePreferences.forecastsVisible(.energy) }
    ) {
        self.networkManager = networkManager
        self.showForecasts = showForecasts
    }

    func refreshData(for location: Location) async throws -> [ProcessSensor] {
        try Task.checkCancellation()
        // The quote, history and LNG are independent: a failed endpoint does not cost the others their data.
        async let brentData = EnergyService.fetchBrent(networkManager: self.networkManager)
        async let brentHistoryData = EnergyService.fetchBrentHistory(networkManager: self.networkManager)
        async let spotData = EnergyService.fetchBrentSpot(networkManager: self.networkManager)
        async let gasData = EnergyService.fetchGas(networkManager: self.networkManager)
        async let lngData = EnergyService.fetchLNG(networkManager: self.networkManager)
        async let stocksData = EnergyService.fetchStocks(networkManager: self.networkManager)
        async let stockHistoryData = EnergyService.fetchStockHistory(networkManager: self.networkManager)
        let (brent, brentHistory, spot, gas, lng) = try await (brentData, brentHistoryData, spotData, gasData, lngData)
        let (stocks, stockHistory) = try await (stocksData, stockHistoryData)
        try Task.checkCancellation()

        let now = Date.now
        var prices: [ProcessSelector: [ProcessValue<Dimension>]] = [:]
        prices[.energy(.brent)] = Self.parseBrent(history: brentHistory, quote: brent, now: now)
        if let spot { prices[.energy(.brentSpot)] = Self.parseBrentSpot(spot, now: now) }
        if let gas { prices[.energy(.ttf)] = Self.parseTTF(gas, now: now) }
        if let lng = lng {
            prices[.energy(.lng)] = Self.parseLNG(lng)
        }
        var measurements = prices.mapValues { Self.series($0, until: now) }.filter { $0.value.isEmpty == false }
        // Monthly levels, not filled day by day like the prices; their estimate only bridges the months not reported yet.
        let stockSeries = Self.stockSeries(
            history: stockHistory.map { Self.parseStockHistory($0) } ?? [:], latest: stocks.map { Self.parseLatestStocks($0) } ?? [:])
        for (energy, values) in stockSeries where values.isEmpty == false {
            measurements[.energy(energy)] = values
        }
        // The estimate is fitted on the trading days themselves, not on the weekends carried forward for the chart.
        var forecasts: [ProcessSelector: ProcessForecast] = [:]
        if self.showForecasts() == true {
            for (selector, values) in prices where measurements[selector] != nil {
                forecasts[selector] = Self.estimate(
                    from: values.filter { $0.timestamp >= now.addingTimeInterval(-Self.span) }, horizon: Self.horizon(for: selector), now: now)
            }
            for (energy, values) in stockSeries {
                forecasts[.energy(energy)] = Self.stockEstimate(from: values, now: now)
            }
        }
        // Nothing at all means nothing is published, so the last prices stay on screen.
        if measurements.isEmpty == true {
            trace.error("No energy prices could be read")
            return []
        }
        let sensor = ProcessSensor(
            name: "Energy", location: Self.location, placemark: "EuroOilWatch · ACER", customData: ["icon": "fuelpump"],
            measurements: measurements,
            timestamp: now, forecasts: forecasts)
        return [sensor]
    }

    /// Nobody publishes a free forecast of these prices, and a price already holds what the market expects, so the estimate is the last
    /// price, with a band as wide as a year of daily moves says it should be after so many days. In logarithms, since prices move in
    /// proportion and cannot go below zero, which makes the band wider above than below. Weekends between trading days are interpolated,
    /// so the band grows per calendar day. Not continued when the source has not updated for ten days.
    static func estimate(from raw: [ProcessValue<Dimension>], horizon: Int = 30, now: Date = .now) -> ProcessForecast? {
        return SeriesEstimate.make(
            from: raw, model: RandomWalkModel(), request: ForecastRequest(step: 24 * 3600, horizon: horizon, transform: .logarithm),
            maximumAge: 10 * 24 * 3600, now: now)
    }

    /// Days of estimate per price. TTF has only about a month of history, so 30 days of estimate took half its chart; four keep the
    /// measured month across the width. The others have a year behind them and keep 30.
    static func horizon(for selector: ProcessSelector) -> Int {
        return selector == .energy(.ttf) ? 4 : 30
    }

    // MARK: - Parsing

    /// EuroOilWatch's futures history plus its latest quote. A quote replaces that session's close or extends the history, never an older
    /// session. Either endpoint can stand alone. Session dates stay at midnight UTC for daily chart markers; download timestamps never
    /// become observation dates, so a previous close cannot masquerade as today's price. Source details travel with the value.
    static func parseBrent(history: Data?, quote: Data?, now: Date = .now) -> [ProcessValue<Dimension>] {
        var values: [Date: ProcessValue<Dimension>] = [:]
        if let history = history,
            let object = try? JSONSerialization.jsonObject(with: history) as? [String: Any],
            let entries = object["entries"] as? [[String: Any]]
        {
            for entry in entries {
                if let value = Self.brentValue(from: entry, dateKey: "date", now: now) {
                    values[value.timestamp] = value
                }
            }
        }
        if let quote = quote,
            let object = try? JSONSerialization.jsonObject(with: quote) as? [String: Any],
            let value = Self.brentValue(from: object, dateKey: "sessionDate", now: now)
        {
            if value.timestamp >= (values.keys.max() ?? .distantPast) {
                values[value.timestamp] = value
            }
        }
        return values.values.sorted(by: { $0.timestamp < $1.timestamp })
    }

    /// EIA's dated spot observations are independent of the futures series and retain their publication lag.
    static func parseBrentSpot(_ data: Data, now: Date = .now) -> [ProcessValue<Dimension>] {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let entries = object["entries"] as? [[String: Any]]
        else { return [] }
        var values: [Date: ProcessValue<Dimension>] = [:]
        for entry in entries {
            if let value = Self.brentValue(from: entry, dateKey: "date", now: now) {
                values[value.timestamp] = ProcessValue(
                    value: value.value, customData: ["source": "EIA via EuroOilWatch"], quality: .good, timestamp: value.timestamp)
            }
        }
        return values.values.sorted { $0.timestamp < $1.timestamp }
    }

    /// The gas endpoint has no dated current TTF quote. Use its dated history only, never the feed's download time.
    static func parseTTF(_ data: Data, now: Date = .now) -> [ProcessValue<Dimension>] {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let entries = object["history"] as? [[String: Any]]
        else { return [] }
        var values: [Date: ProcessValue<Dimension>] = [:]
        for entry in entries {
            if let text = entry["date"] as? String, let date = Self.date(from: text), date <= now,
                let price = entry["ttfEurMwh"] as? Double, price.isFinite == true, price > 0
            {
                values[date] = ProcessValue(
                    value: Measurement(value: price, unit: UnitGasPrice.eurosPerMegawattHour),
                    customData: ["source": "Yahoo Finance via EuroOilWatch", "instrument": "TTF front-month futures"], quality: .good,
                    timestamp: date)
            }
        }
        return values.values.sorted { $0.timestamp < $1.timestamp }
    }

    private static func brentValue(from row: [String: Any], dateKey: String, now: Date) -> ProcessValue<Dimension>? {
        guard let text = row[dateKey] as? String, let date = Self.date(from: text), date <= now,
            let price = row["priceUsd"] as? Double, price.isFinite == true, price > 0
        else { return nil }
        var details: [String: Any] = ["source": "EuroOilWatch", "sessionDate": text]
        for key in ["contract", "contractLabel", "observedAt", "quoteType", "quoteStatus", "staleReason"] {
            if let value = row[key] as? String {
                details[key] = value
            }
        }
        return ProcessValue<Dimension>(
            value: Measurement(value: price, unit: UnitOilPrice.usDollarsPerBarrel), customData: details, quality: .good, timestamp: date)
    }

    /// ACER's export: quoted fields, newest first, `DATE, NORTH-WEST EUROPE, SOUTH EUROPE, EU, LNG BENCHMARK` in EUR/MWh. The EU price is
    /// the one reported; the early rows have none, and the benchmark is a spread that can be negative, so neither is used.
    static func parseLNG(_ data: Data) -> [ProcessValue<Dimension>] {
        var values: [ProcessValue<Dimension>] = []
        for fields in Self.rows(of: data) where fields.count >= 4 {
            if let date = Self.date(from: fields[0]), let price = Double(fields[3]) {
                values.append(
                    ProcessValue<Dimension>(
                        value: Measurement(value: price, unit: UnitGasPrice.eurosPerMegawattHour), quality: .good, timestamp: date))
            }
        }
        return values.sorted(by: { $0.timestamp < $1.timestamp })
    }

    /// The prices of the last `span`, one per day: markets are closed at weekends and on holidays, so those days carry the last price
    /// forward as uncertain, which keeps a dragged chart marker landing on a value. The series ends on the last day with a price.
    static func series(
        _ values: [ProcessValue<Dimension>], until now: Date, span: TimeInterval = EnergyController.span
    ) -> [ProcessValue<Dimension>] {
        let start = now.addingTimeInterval(-span)
        let recent = values.filter { $0.timestamp >= start }
        guard let first = recent.first, let last = recent.last else { return [] }
        var series: [ProcessValue<Dimension>] = []
        var previous = first
        var day = first.timestamp
        while day <= last.timestamp {
            if let match = recent.first(where: { $0.timestamp == day }) {
                previous = match
                series.append(match)
            }
            else {
                series.append(ProcessValue<Dimension>(value: previous.value, quality: .uncertain, timestamp: day))
            }
            day = day.addingTimeInterval(24 * 60 * 60)
        }
        return series
    }

    // MARK: - Fuel stocks

    /// EuroOilWatch's history: per country, a row per month with `petrolDays`, `dieselDays` and `jetDays`, the days the stock would last
    /// at that month's consumption, from Eurostat. A month is dated at its last day, since the stock is the one held at its end; a month
    /// without a figure is skipped, which the latest row often is.
    static func parseStockHistory(
        _ data: Data, country: String = EnergyController.stockCountry
    ) -> [ProcessSelector.Energy: [ProcessValue<Dimension>]] {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let countries = object["countries"] as? [[String: Any]],
            let rows = countries.first(where: { $0["countryCode"] as? String == country })?["data"] as? [[String: Any]]
        else { return [:] }
        let keys: [(ProcessSelector.Energy, String)] = [(.petrolStock, "petrolDays"), (.dieselStock, "dieselDays"), (.jetFuelStock, "jetDays")]
        var series: [ProcessSelector.Energy: [ProcessValue<Dimension>]] = [:]
        for row in rows {
            guard let period = row["period"] as? String, let date = Self.monthEnd(from: period) else { continue }
            for (energy, key) in keys {
                if let days = row[key] as? Double, days.isFinite == true, days >= 0 {
                    series[energy, default: []].append(Self.stockValue(days: days, period: period, date: date))
                }
            }
        }
        return series.mapValues { values in
            return values.sorted { $0.timestamp < $1.timestamp }
        }
    }

    /// The latest month from EuroOilWatch's stocks endpoint. It says how each figure was obtained: one carried forward from an earlier
    /// month, estimated or capped is uncertain. It also has the tonnes behind the days, EuroOilWatch's status and the minimum it holds
    /// the stock against, which travel in `customData`.
    static func parseLatestStocks(
        _ data: Data, country: String = EnergyController.stockCountry
    ) -> [ProcessSelector.Energy: ProcessValue<Dimension>] {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let countries = object["countries"] as? [[String: Any]],
            let fuels = countries.first(where: { $0["countryCode"] as? String == country })?["fuels"] as? [[String: Any]]
        else { return [:] }
        let types: [String: ProcessSelector.Energy] = ["petrol": .petrolStock, "diesel": .dieselStock, "jet_fuel": .jetFuelStock]
        var latest: [ProcessSelector.Energy: ProcessValue<Dimension>] = [:]
        for fuel in fuels {
            guard let type = fuel["fuelType"] as? String, let energy = types[type], let days = fuel["daysOfSupply"] as? Double,
                days.isFinite == true, days >= 0
            else { continue }
            let provenance = fuel["provenance"] as? [String: Any] ?? [:]
            guard let period = provenance["stockPeriod"] as? String, let date = Self.monthEnd(from: period) else { continue }
            let observed =
                provenance["observation"] as? String == "observed" && provenance["carriedForward"] as? Bool != true
                && provenance["capped"] as? Bool != true
            var details: [String: Any] = ["observation": provenance["observation"] as? String ?? "unknown"]
            // EuroOilWatch's own assessment, from critical to safe, and the level it measures against, shown on the chart.
            if let status = fuel["status"] as? String {
                details["status"] = status
            }
            if let minimum = fuel["mandatoryMinimumDays"] as? Double {
                details["mandatoryMinimumDays"] = minimum
            }
            if let stock = fuel["stockKilotonnes"] as? Double {
                details["stockKilotonnes"] = stock
            }
            if let consumption = fuel["consumptionKilotonnes"] as? Double {
                details["consumptionKilotonnes"] = consumption
            }
            latest[energy] = Self.stockValue(
                days: days, period: period, date: date, quality: observed == true ? .good : .uncertain, details: details)
        }
        return latest
    }

    /// The months a stock series has not reported yet, up to today. Eurostat's figures arrive two to three months late, so the chart would
    /// otherwise stop well short of now. A damped trend in days of supply on a monthly grid, never below zero, which falls back to the
    /// last value where that did better on the series' own past; a month at a time from the last report, with the last point today. Not
    /// continued when the last report is more than half a year old.
    static func stockEstimate(from values: [ProcessValue<Dimension>], now: Date = .now) -> ProcessForecast? {
        guard let last = values.last, now > last.timestamp else { return nil }
        let month = 365.25 / 12 * 24 * 3600
        let horizon = Int((now.timeIntervalSince(last.timestamp) / month).rounded(.up))
        guard
            let forecast = SeriesEstimate.make(
                from: values, model: DampedTrendModel(),
                request: ForecastRequest(step: month, horizon: horizon, bounds: 0 ... 10_000, maximumGap: 3 * month),
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

    /// The history with the latest month laid over it: the latest figure replaces the history's for the same month, since it says how it
    /// was obtained, and is added when the history does not have that month yet. The two endpoints do not always end in the same month.
    static func stockSeries(
        history: [ProcessSelector.Energy: [ProcessValue<Dimension>]], latest: [ProcessSelector.Energy: ProcessValue<Dimension>]
    ) -> [ProcessSelector.Energy: [ProcessValue<Dimension>]] {
        var series = history
        for (energy, value) in latest {
            var values = series[energy, default: []].filter { $0.timestamp != value.timestamp }
            values.append(value)
            series[energy] = values.sorted { $0.timestamp < $1.timestamp }
        }
        return series
    }

    private static func stockValue(
        days: Double, period: String, date: Date, quality: ProcessQuality = .good, details: [String: Any] = [:]
    ) -> ProcessValue<Dimension> {
        var customData = details
        customData["source"] = "Eurostat via EuroOilWatch"
        customData["period"] = period
        return ProcessValue<Dimension>(
            value: Measurement(value: days, unit: UnitSupplyDays.days), customData: customData, quality: quality, timestamp: date)
    }

    /// `yyyy-MM` as midnight UTC on the last day of that month.
    static func monthEnd(from text: String) -> Date? {
        guard let start = Self.monthFormatter.date(from: text), Self.monthFormatter.string(from: start) == text,
            let next = Self.utcCalendar.date(byAdding: .month, value: 1, to: start)
        else { return nil }
        return Self.utcCalendar.date(byAdding: .day, value: -1, to: next)
    }

    private static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM"
        return formatter
    }()

    // MARK: - CSV

    /// ACER's CSV fields, without quotes and without the header. Its export uses ISO 8859-1; UTF-8 is accepted as well.
    static func rows(of data: Data) -> [[String]] {
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else { return [] }
        let lines = text.components(separatedBy: .newlines).filter { $0.isEmpty == false }
        return lines.dropFirst().map { line in
            return line.components(separatedBy: ",").map { field in
                return field.trimmingCharacters(in: CharacterSet(charactersIn: "\" \r"))
            }
        }
    }

    /// `yyyy-MM-dd` as midnight UTC, which is where the chart's drag rounding lands, so a dragged marker finds the day's value.
    static func date(from text: String) -> Date? {
        guard let date = Self.formatter.date(from: text), Self.formatter.string(from: date) == text else { return nil }
        return date
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
