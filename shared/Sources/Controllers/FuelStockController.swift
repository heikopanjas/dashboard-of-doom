import DoomKitLocation
import DoomKitNetwork
import DoomKitProcess
import DoomKitServices
import DoomKitTools
import Foundation

/// Germany's fuel stocks, petrol, diesel and jet fuel, in days of supply, monthly from Eurostat via EuroOilWatch, and this week's national
/// average pump prices from the EU Weekly Oil Bulletin, which travel in `customData["nationalPrices"]` since they are one week's figures,
/// not a series. A national figure has no place, so the sensor's location is nominal and never shown, and the source is not on the map.
class FuelStockController: ProcessController {
    /// The country whose fuel stocks are shown. Germany, whatever the reader's location, like the rest of the app's data.
    static let stockCountry = "DE"

    /// Nominal, never shown: a national figure has no place. Berlin, since that is where the app looks by default.
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
        // The history, the latest month and the weekly prices are independent: any one of them still gives something to show.
        async let stocksData = EnergyService.fetchStocks(networkManager: self.networkManager)
        async let historyData = EnergyService.fetchStockHistory(networkManager: self.networkManager)
        async let pricesData = EnergyService.fetchFuelPrices(networkManager: self.networkManager)
        let (stocks, history, prices) = try await (stocksData, historyData, pricesData)
        try Task.checkCancellation()

        let now = Date.now
        // Monthly levels, not filled day by day like the prices; their estimate only bridges the months not reported yet.
        let series = Self.stockSeries(
            history: history.map { Self.parseStockHistory($0) } ?? [:], latest: stocks.map { Self.parseLatestStocks($0) } ?? [:])
        var measurements: [ProcessSelector: [ProcessValue<Dimension>]] = [:]
        var forecasts: [ProcessSelector: ProcessForecast] = [:]
        for (energy, values) in series where values.isEmpty == false {
            measurements[.energy(energy)] = values
            if self.showForecasts() == true {
                forecasts[.energy(energy)] = SeriesEstimate.monthly(from: values, bounds: 0 ... 10_000, now: now)
            }
        }
        let national = prices.flatMap { Self.parseNationalPrices($0) }
        // Nothing at all means nothing is published, so the last figures stay on screen.
        if measurements.isEmpty == true && national == nil {
            trace.error("No fuel stocks or prices could be read")
            return []
        }
        var customData: [String: Any] = ["icon": "shippingbox"]
        if let national {
            customData["nationalPrices"] = national
        }
        let sensor = ProcessSensor(
            name: "Fuel Stocks", location: Self.location, placemark: "EuroOilWatch · Eurostat", customData: customData,
            measurements: measurements, timestamp: now, forecasts: forecasts)
        return [sensor]
    }

    /// EuroOilWatch's history: per country, a row per month with `petrolDays`, `dieselDays` and `jetDays`, the days the stock would last
    /// at that month's consumption, from Eurostat. A month is dated at its last day, since the stock is the one held at its end; a month
    /// without a figure is skipped, which the latest row often is.
    static func parseStockHistory(
        _ data: Data, country: String = FuelStockController.stockCountry
    ) -> [ProcessSelector.Energy: [ProcessValue<Dimension>]] {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let countries = object["countries"] as? [[String: Any]],
            let rows = countries.first(where: { $0["countryCode"] as? String == country })?["data"] as? [[String: Any]]
        else { return [:] }
        let keys: [(ProcessSelector.Energy, String)] = [(.petrolStock, "petrolDays"), (.dieselStock, "dieselDays"), (.jetFuelStock, "jetDays")]
        var series: [ProcessSelector.Energy: [ProcessValue<Dimension>]] = [:]
        for row in rows {
            guard let period = row["period"] as? String, let date = Date.monthEnd(from: period) else { continue }
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
        _ data: Data, country: String = FuelStockController.stockCountry
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
            guard let period = provenance["stockPeriod"] as? String, let date = Date.monthEnd(from: period) else { continue }
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

    /// EuroOilWatch's latest Weekly Oil Bulletin: `bulletinDate`, per country `petrolPrice` and `dieselPrice` in euros per litre, and
    /// `euAverage`. Nil without the country's two prices.
    static func parseNationalPrices(_ data: Data, country: String = FuelStockController.stockCountry) -> NationalFuelPrices? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let date = object["bulletinDate"] as? String,
            let entry = (object["countries"] as? [[String: Any]])?.first(where: { $0["countryCode"] as? String == country }),
            let petrol = entry["petrolPrice"] as? Double, let diesel = entry["dieselPrice"] as? Double, petrol > 0, diesel > 0
        else { return nil }
        let average = object["euAverage"] as? [String: Any]
        return NationalFuelPrices(
            bulletinDate: date, petrol: petrol, diesel: diesel, euPetrol: average?["petrolPrice"] as? Double,
            euDiesel: average?["dieselPrice"] as? Double)
    }
}
