import DoomKitLocation
import DoomKitNetwork
import DoomKitProcess
import DoomKitServices
import DoomKitTools
import Foundation

/// The oil production of six Gulf producers, monthly from EIA's international data via AmericasOilWatch: total petroleum and other
/// liquids, which is crude with condensate and natural gas liquids, in million barrels a day. Each country is a sensor at a fixed point,
/// its capital, since the feed has no coordinates and the six share a map.
class ProducerController: ProcessController {
    struct Producer: Sendable, Equatable {
        /// The feed's ISO 3166 alpha-3 code, also the sensor's stable `sourceID`.
        let code: String
        let name: String
        let location: Location
    }

    /// The Gulf six, in the order the map and the charts show them: the order sets the label priority and the colours.
    static let producers: [Producer] = [
        Producer(code: "SAU", name: "Saudi Arabia", location: Location(latitude: 24.7136, longitude: 46.6753)),
        Producer(code: "ARE", name: "UAE", location: Location(latitude: 24.4539, longitude: 54.3773)),
        Producer(code: "IRN", name: "Iran", location: Location(latitude: 35.6892, longitude: 51.3890)),
        Producer(code: "IRQ", name: "Iraq", location: Location(latitude: 33.3152, longitude: 44.3661)),
        Producer(code: "KWT", name: "Kuwait", location: Location(latitude: 29.3759, longitude: 47.9774)),
        Producer(code: "OMN", name: "Oman", location: Location(latitude: 23.5880, longitude: 58.3829))
    ]

    /// The first day the charts show, the user's choice: from 2025 on. The estimate still learns from the feed's whole history.
    static let chartStart = EnergyController.date(from: "2025-01-01") ?? .distantPast

    /// What one country reported: its OPEC membership and its production by month.
    struct Series {
        let group: String?
        let values: [ProcessValue<Dimension>]
    }

    private let networkManager: NetworkManager
    private let showForecasts: @Sendable () -> Bool

    init(
        networkManager: NetworkManager = .shared,
        showForecasts: @escaping @Sendable () -> Bool = { return SourcePreferences.forecastsVisible(.markets) }
    ) {
        self.networkManager = networkManager
        self.showForecasts = showForecasts
    }

    func refreshData(for location: Location) async throws -> [ProcessSensor] {
        try Task.checkCancellation()
        let data = try await ProductionService.fetchOPEC(networkManager: self.networkManager)
        try Task.checkCancellation()
        // Nothing fetched means nothing is published, so the last figures stay on screen.
        guard let data else { return [] }
        let now = Date.now
        let series = Self.parseProduction(data)
        let sensors = Self.producers.compactMap { producer -> ProcessSensor? in
            guard let country = series[producer.code] else { return nil }
            let shown = country.values.filter { $0.timestamp >= Self.chartStart }
            guard shown.isEmpty == false else { return nil }
            var forecasts: [ProcessSelector: ProcessForecast] = [:]
            if self.showForecasts() == true {
                forecasts[.energy(.production)] = SeriesEstimate.monthly(from: country.values, bounds: 0 ... 50, now: now)
            }
            var customData: [String: Any] = ["icon": "drop.fill"]
            if let group = country.group {
                customData["group"] = group
            }
            return ProcessSensor(
                name: producer.name, location: producer.location, placemark: producer.name, customData: customData,
                measurements: [.energy(.production): shown], timestamp: now, sourceID: producer.code, forecasts: forecasts)
        }
        if sensors.isEmpty == true {
            trace.error("No oil production could be read")
        }
        return sensors
    }

    /// AmericasOilWatch's members, by code: each with `history`, a row per month with `period` and `kbpd`, and the latest month as
    /// `latestKbpd` and `latestPeriod`, which replaces the history's figure for that month or is added after it. A month is dated at its
    /// last day, midnight UTC, like the fuel stocks; a month without a figure is skipped.
    static func parseProduction(_ data: Data) -> [String: Series] {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let members = object["members"] as? [[String: Any]]
        else { return [:] }
        var series: [String: Series] = [:]
        for member in members {
            guard let code = member["code"] as? String else { continue }
            var byDate: [Date: ProcessValue<Dimension>] = [:]
            for row in member["history"] as? [[String: Any]] ?? [] {
                if let value = Self.value(period: row["period"] as? String, kbpd: row["kbpd"] as? Double) {
                    byDate[value.timestamp] = value
                }
            }
            if let latest = Self.value(period: member["latestPeriod"] as? String, kbpd: member["latestKbpd"] as? Double) {
                byDate[latest.timestamp] = latest
            }
            series[code] = Series(group: member["group"] as? String, values: byDate.values.sorted { $0.timestamp < $1.timestamp })
        }
        return series
    }

    /// Thousand barrels a day as million barrels a day, at the end of its month.
    private static func value(period: String?, kbpd: Double?) -> ProcessValue<Dimension>? {
        guard let period, let kbpd, kbpd.isFinite == true, kbpd >= 0, let date = Date.monthEnd(from: period) else { return nil }
        return ProcessValue<Dimension>(
            value: Measurement(value: kbpd / 1000, unit: UnitOilProduction.millionBarrelsPerDay),
            customData: ["source": "EIA via AmericasOilWatch", "period": period], quality: .good, timestamp: date)
    }
}
