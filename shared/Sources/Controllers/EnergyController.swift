import DoomKitLocation
import DoomKitNetwork
import DoomKitProcess
import DoomKitServices
import DoomKitTools
import Foundation

/// Global energy prices: Brent and WTI crude oil, and the EU's LNG price. Prices have no place, so the sensor's location is nominal and
/// never shown, and the source is not on the map.
class EnergyController: ProcessController {
    /// A year of prices: enough to show a trend and the winter and summer swing of gas, and still one point per two or three pixels on
    /// a phone.
    static let span: TimeInterval = 365 * 24 * 60 * 60

    /// Nominal, never shown: prices have no place. Berlin, since that is where the app looks by default.
    private static let location = Location(latitude: 52.5186, longitude: 13.3763)

    private let networkManager: NetworkManager
    private let showForecasts: @Sendable () -> Bool

    init(networkManager: NetworkManager = .shared, showForecasts: @escaping @Sendable () -> Bool = { return SourcePreferences.forecastsVisible(.energy) }) {
        self.networkManager = networkManager
        self.showForecasts = showForecasts
    }

    func refreshData(for location: Location) async throws -> [ProcessSensor] {
        try Task.checkCancellation()
        // The three files are independent, so a failed one drops only its series.
        async let brentData = EnergyService.fetchBrent(networkManager: self.networkManager)
        async let wtiData = EnergyService.fetchWTI(networkManager: self.networkManager)
        async let lngData = EnergyService.fetchLNG(networkManager: self.networkManager)
        let (brent, wti, lng) = try await (brentData, wtiData, lngData)
        try Task.checkCancellation()

        let now = Date.now
        var prices: [ProcessSelector: [ProcessValue<Dimension>]] = [:]
        if let brent = brent {
            prices[.energy(.brent)] = Self.parseOil(brent, unit: UnitOilPrice.usDollarsPerBarrel)
        }
        if let wti = wti {
            prices[.energy(.wti)] = Self.parseOil(wti, unit: UnitOilPrice.usDollarsPerBarrel)
        }
        if let lng = lng {
            prices[.energy(.lng)] = Self.parseLNG(lng)
        }
        let measurements = prices.mapValues { Self.series($0, until: now) }.filter { $0.value.isEmpty == false }
        // The estimate is fitted on the trading days themselves, not on the weekends carried forward for the chart.
        var forecasts: [ProcessSelector: ProcessForecast] = [:]
        if self.showForecasts() == true {
            for (selector, values) in prices where measurements[selector] != nil {
                forecasts[selector] = Self.estimate(from: values.filter { $0.timestamp >= now.addingTimeInterval(-Self.span) }, now: now)
            }
        }
        // Nothing at all means nothing is published, so the last prices stay on screen.
        if measurements.isEmpty == true {
            trace.error("No energy prices could be read")
            return []
        }
        let sensor = ProcessSensor(
            name: "Energy", location: Self.location, placemark: "EIA · ACER", customData: ["icon": "fuelpump"], measurements: measurements,
            timestamp: now, forecasts: forecasts)
        return [sensor]
    }

    /// Nobody publishes a free forecast of these prices, and a price already holds what the market expects, so the estimate is the last
    /// price, with a band as wide as a year of daily moves says it should be after so many days. In logarithms, since prices move in
    /// proportion and cannot go below zero, which makes the band wider above than below. Weekends between trading days are interpolated,
    /// so the band grows per calendar day. Not continued when the mirror has not updated for ten days.
    static func estimate(from raw: [ProcessValue<Dimension>], now: Date = .now) -> ProcessForecast? {
        return SeriesEstimate.make(
            from: raw, model: RandomWalkModel(), request: ForecastRequest(step: 24 * 3600, horizon: 30, transform: .logarithm),
            maximumAge: 10 * 24 * 3600, now: now)
    }

    // MARK: - Parsing

    /// A `Date,Price` file, one row per trading day, as the oil-prices project writes it. Rows that do not parse are skipped, and the
    /// order of the file does not matter.
    static func parseOil(_ data: Data, unit: Dimension) -> [ProcessValue<Dimension>] {
        var values: [ProcessValue<Dimension>] = []
        for fields in Self.rows(of: data) where fields.count >= 2 {
            if let date = Self.date(from: fields[0]), let price = Double(fields[1]) {
                values.append(ProcessValue<Dimension>(value: Measurement(value: price, unit: unit), quality: .good, timestamp: date))
            }
        }
        return values.sorted(by: { $0.timestamp < $1.timestamp })
    }

    /// ACER's export: quoted fields, newest first, `DATE, NORTH-WEST EUROPE, SOUTH EUROPE, EU, LNG BENCHMARK` in EUR/MWh. The EU price is
    /// the one reported; the early rows have none, and the benchmark is a spread that can be negative, so neither is used.
    static func parseLNG(_ data: Data) -> [ProcessValue<Dimension>] {
        var values: [ProcessValue<Dimension>] = []
        for fields in Self.rows(of: data) where fields.count >= 4 {
            if let date = Self.date(from: fields[0]), let price = Double(fields[3]) {
                values.append(
                    ProcessValue<Dimension>(value: Measurement(value: price, unit: UnitGasPrice.eurosPerMegawattHour), quality: .good, timestamp: date))
            }
        }
        return values.sorted(by: { $0.timestamp < $1.timestamp })
    }

    /// The prices of the last `span`, one per day: markets are closed at weekends and on holidays, so those days carry the last price
    /// forward as uncertain, which keeps a dragged chart marker landing on a value. The series ends on the last day with a price.
    static func series(_ values: [ProcessValue<Dimension>], until now: Date, span: TimeInterval = EnergyController.span) -> [ProcessValue<Dimension>] {
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

    // MARK: - CSV

    /// The rows of a CSV as their fields, without quotes and without the header. ACER writes ISO 8859-1, the oil files UTF-8; both are
    /// ASCII where it matters, and Latin-1 decodes any byte, so it is the fallback.
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
        return Self.formatter.date(from: text)
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
