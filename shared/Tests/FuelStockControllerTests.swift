import DoomKitLocation
import DoomKitNetwork
import DoomKitProcess
import Foundation
import Synchronization
import Testing

@Suite struct FuelStockControllerTests {
    private actor Monitor: NetworkMonitoring {
        func start(_ receive: @escaping @Sendable (Bool, ConnectionType) -> Void) { receive(true, .wifi) }
        func stop() {}
    }

    /// EuroOilWatch's bulletin, trimmed: Germany, another country and the EU average.
    private static let weeklyPrices = """
        {"bulletinDate":"2026-10-19","countries":[
        {"countryCode":"AT","petrolPrice":1.8,"dieselPrice":1.9},
        {"countryCode":"DE","countryName":"Germany","petrolPrice":2.179,"dieselPrice":2.266}],
        "euAverage":{"petrolPrice":1.932,"dieselPrice":2.084}}
        """

    @Test func theWeeklyPricesAreGermanysAndTheEUs() throws {
        let prices = try #require(FuelStockController.parseNationalPrices(Data(Self.weeklyPrices.utf8)))
        #expect(prices == NationalFuelPrices(bulletinDate: "2026-10-19", petrol: 2.179, diesel: 2.266, euPetrol: 1.932, euDiesel: 2.084))
        #expect(FuelStockController.parseNationalPrices(Data(Self.weeklyPrices.utf8), country: "FR") == nil)
        #expect(FuelStockController.parseNationalPrices(Data("{}".utf8)) == nil)
    }

    private static func utcMidnight(_ text: String) -> Date? {
        return EnergyController.date(from: text)
    }

    /// EuroOilWatch's history, trimmed: Germany with a month whose figures are missing, and another country that must be ignored.
    private static let stockHistory = """
        {"periods":["2026-06","2026-07"],"countries":[
        {"countryCode":"AT","data":[{"period":"2026-07","petrolDays":91.2,"dieselDays":69.8,"jetDays":38.2}]},
        {"countryCode":"DE","data":[
        {"period":"2026-08","petrolDays":57.8,"dieselDays":119.3,"jetDays":55.2},
        {"period":"2026-07","petrolDays":54.1,"dieselDays":102.5,"jetDays":55.5},
        {"period":"2026-09","petrolDays":null,"dieselDays":null,"jetDays":null},
        {"period":"not a month","petrolDays":1}]}]}
        """

    /// EuroOilWatch's latest month, trimmed: an observed petrol figure, a carried-forward diesel one and jet fuel without a figure.
    private static let latestStocks = """
        {"dataPeriod":"2026-07","countries":[{"countryCode":"DE","fuels":[
        {"fuelType":"petrol","stockKilotonnes":2669.575,"consumptionKilotonnes":1480.768,"daysOfSupply":54.1,
        "mandatoryMinimumDays":90,"status":"critical",
        "provenance":{"stockPeriod":"2026-07","observation":"observed","carriedForward":false,"capped":false}},
        {"fuelType":"diesel","stockKilotonnes":10099.474,"daysOfSupply":102.5,
        "provenance":{"stockPeriod":"2026-07","observation":"observed","carriedForward":true,"capped":false}},
        {"fuelType":"jet_fuel","daysOfSupply":null,"provenance":{"stockPeriod":"2026-07","observation":"unassessed"}}]}]}
        """

    @Test func stockHistoryIsGermanysMonthsAtTheirLastDayInDaysOfSupply() throws {
        let series = FuelStockController.parseStockHistory(Data(Self.stockHistory.utf8))
        let petrol = try #require(series[.petrolStock])
        #expect(petrol.map { $0.value.value } == [54.1, 57.8])
        let july = try #require(Self.utcMidnight("2026-07-31"))
        let august = try #require(Self.utcMidnight("2026-08-31"))
        #expect(petrol.map { $0.timestamp } == [july, august])
        #expect(petrol.allSatisfy { $0.value.unit == UnitSupplyDays.days } == true)
        #expect(petrol.first?.customData?["period"] as? String == "2026-07")
        #expect(series[.dieselStock]?.last?.value.value == 119.3)
        #expect(series[.jetFuelStock]?.count == 2)
        #expect(FuelStockController.parseStockHistory(Data(Self.stockHistory.utf8), country: "FR").isEmpty == true)
        #expect(FuelStockController.parseStockHistory(Data("not json".utf8)).isEmpty == true)
    }

    @Test func theLatestStockIsUncertainUnlessObservedAndCarriesItsTonnes() throws {
        let latest = FuelStockController.parseLatestStocks(Data(Self.latestStocks.utf8))
        let petrol = try #require(latest[.petrolStock])
        #expect(petrol.quality == .good)
        #expect(petrol.timestamp == Self.utcMidnight("2026-07-31"))
        #expect(petrol.customData?["stockKilotonnes"] as? Double == 2669.575)
        #expect(EnergyDisplay.status(in: [petrol]) == "critical")
        #expect(EnergyDisplay.statusPeriod(in: [petrol]) == "2026-07")
        #expect(EnergyDisplay.minimumDays(in: [petrol]) == 90)
        #expect(EnergyDisplay.minimumDays(in: [try #require(latest[.dieselStock])]) == nil)
        #expect(latest[.dieselStock]?.quality == .uncertain)
        #expect(latest[.jetFuelStock] == nil)
    }

    @Test func theLatestStockReplacesItsMonthAndIsAddedWhenNewer() throws {
        let history = FuelStockController.parseStockHistory(Data(Self.stockHistory.utf8))
        let latest = FuelStockController.parseLatestStocks(Data(Self.latestStocks.utf8))
        let series = FuelStockController.stockSeries(history: history, latest: latest)
        // July comes from the latest endpoint, uncertain, and August stays: the history can be a month ahead.
        let diesel = try #require(series[.dieselStock])
        #expect(diesel.map { $0.value.value } == [102.5, 119.3])
        #expect(diesel.map { $0.quality } == [.uncertain, .good])
        let june = try #require(Self.utcMidnight("2026-06-30"))
        let older = ProcessValue<Dimension>(value: Measurement(value: 1, unit: UnitSupplyDays.days), quality: .good, timestamp: june)
        let newer = FuelStockController.stockSeries(history: [.jetFuelStock: [older]], latest: [.jetFuelStock: try #require(latest[.petrolStock])])
        let july = try #require(Self.utcMidnight("2026-07-31"))
        #expect(newer[.jetFuelStock]?.map { $0.timestamp } == [june, july])
    }

    @Test func aMonthEndsOnItsLastDayAndOnlyMonthsParse() {
        #expect(Date.monthEnd(from: "2028-02") == Self.utcMidnight("2028-02-29"))
        #expect(Date.monthEnd(from: "2026-12") == Self.utcMidnight("2026-12-31"))
        #expect(Date.monthEnd(from: "2026-13") == nil)
        #expect(Date.monthEnd(from: "2026-7") == nil)
        #expect(Date.monthEnd(from: "2026-07-01") == nil)
    }

    @Test func stocksShowOneDecimalAndTheirMonth() throws {
        let transformer = EnergyTransformer()
        let date = try #require(Self.utcMidnight("2026-07-31"))
        let value = ProcessValue<Dimension>(value: Measurement(value: 54.08, unit: UnitSupplyDays.days), quality: .good, timestamp: date)
        #expect(transformer.renderFaceplate(current: [.energy(.petrolStock): value])[.energy(.petrolStock)] == "54.1 days")
        #expect(EnergyDisplay.dateText(date, for: .energy(.petrolStock)) == date.formatted(.dateTime.month(.abbreviated).year()))
        #expect(EnergyDisplay.dateText(date, for: .energy(.brent)) == date.dateString())
        #expect(EnergyDisplay.title(for: .energy(.jetFuelStock)) == "Jet Fuel")
    }

    private static func monthlyStocks(_ days: [Double], lastMonth: String) throws -> [ProcessValue<Dimension>] {
        let last = try #require(Date.monthEnd(from: lastMonth))
        return days.enumerated().map { index, value in
            let months = days.count - 1 - index
            let date = Calendar(identifier: .gregorian).date(byAdding: .month, value: -months, to: last) ?? last
            return ProcessValue<Dimension>(value: Measurement(value: value, unit: UnitSupplyDays.days), quality: .good, timestamp: date)
        }
    }

    @Test func theStockEstimateBridgesTheUnreportedMonthsAndEndsToday() throws {
        let values = try Self.monthlyStocks(
            [54.6, 49.4, 64.6, 48.4, 51.9, 49.2, 48.7, 53.4, 51.9, 64.2, 63, 62.3, 56.1, 50.3, 43.2, 54.1, 57.8], lastMonth: "2026-08")
        let last = try #require(values.last)
        let now = try #require(ISO8601DateFormatter().date(from: "2026-10-26T15:00:00Z"))
        let forecast = try #require(SeriesEstimate.monthly(from: values, bounds: 0 ... 10_000, now: now))
        #expect(forecast.origin.isProvider == false)
        #expect(forecast.points.last?.timestamp == now)
        #expect(forecast.points.allSatisfy { $0.timestamp > last.timestamp && $0.timestamp <= now } == true)
        // One month on the grid before today: the end of September.
        #expect(forecast.points.count == 2)
        #expect(forecast.points.allSatisfy { $0.value.value >= 0 } == true)
        // Nothing before the last report, and nothing when the reports stopped half a year ago.
        #expect(SeriesEstimate.monthly(from: values, bounds: 0 ... 10_000, now: last.timestamp) == nil)
        #expect(SeriesEstimate.monthly(from: values, bounds: 0 ... 10_000, now: last.timestamp.addingTimeInterval(200 * 24 * 3600)) == nil)
    }

    @Test func aForecastEndsBetweenItsNeighboursAtTheCut() throws {
        let start = try #require(Self.utcMidnight("2026-08-31"))
        let day: TimeInterval = 24 * 3600
        let last = ProcessValue<Dimension>(value: Measurement(value: 50, unit: UnitSupplyDays.days), quality: .good, timestamp: start)
        let point = { (days: Double, value: Double) in
            return ProcessForecast.Point(
                timestamp: start.addingTimeInterval(days * day), value: Measurement(value: value, unit: UnitSupplyDays.days), lower: value - 10,
                upper: value + 10)
        }
        let forecast = ProcessForecast(origin: .estimate("trend"), points: [point(30, 60), point(60, 80)])
        let cut = try #require(SeriesEstimate.ending(forecast, at: start.addingTimeInterval(45 * day), from: last))
        #expect(cut.points.count == 2)
        #expect(cut.points[1].value.value == 70)
        #expect(cut.points[1].lower == 60)
        #expect(cut.points[1].upper == 80)
        // Before the first point the last measurement is the neighbour, without a band of its own.
        let early = try #require(SeriesEstimate.ending(forecast, at: start.addingTimeInterval(15 * day), from: last))
        #expect(early.points.count == 1)
        #expect(early.points[0].value.value == 55)
        #expect(early.points[0].lower == 50)
        #expect(SeriesEstimate.ending(forecast, at: start.addingTimeInterval(90 * day), from: last) == nil)
    }

    @Test func aStocksRangeHoldsItsMinimum() throws {
        let date = try #require(Self.utcMidnight("2026-07-31"))
        let values = [
            ProcessValue<Dimension>(
                value: Measurement(value: 50, unit: UnitSupplyDays.days), quality: .good, timestamp: date.addingTimeInterval(-31 * 86400)),
            ProcessValue<Dimension>(
                value: Measurement(value: 60, unit: UnitSupplyDays.days), customData: ["mandatoryMinimumDays": 90.0], quality: .good,
                timestamp: date)
        ]
        let range = try #require(EnergyTransformer().renderRange(measurements: [.energy(.petrolStock): values])[.energy(.petrolStock)])
        #expect(range.contains(90) == true)
        #expect(abs(range.lowerBound - 49) < 0.001)
    }

    @Test(arguments: ["none", "stocks", "history", "prices", "all"])
    func refreshKeepsEachEndpointAndRequestsAllThree(failure: String) async throws {
        let requests = Mutex<[String]>([])
        let network = NetworkManager(
            transport: { request in
                let url = try #require(request.url)
                requests.withLock { $0.append(url.absoluteString) }
                if failure == "all" || url.lastPathComponent == failure { throw URLError(.cancelled) }
                let text: String
                switch url.lastPathComponent {
                    case "stocks":
                        text =
                            "{\"countries\":[{\"countryCode\":\"DE\",\"fuels\":[{\"fuelType\":\"diesel\",\"daysOfSupply\":102.5,"
                            + "\"provenance\":{\"stockPeriod\":\"2026-07\",\"observation\":\"observed\"}}]}]}"
                    case "prices":
                        text = Self.weeklyPrices
                    default:
                        text = "{\"countries\":[{\"countryCode\":\"DE\",\"data\":[{\"period\":\"2026-06\",\"petrolDays\":43.2}]}]}"
                }
                let response = try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
                return (Data(text.utf8), response)
            }, makeMonitor: { Monitor() }, probeURL: nil)
        let updates = await network.updates()
        await network.startMonitoring()
        for await state in updates where state.isConnected == true { break }
        let sensors = try await FuelStockController(networkManager: network, showForecasts: { false })
            .refreshData(for: Location(latitude: 52.51889, longitude: 13.36528))
        await network.stopMonitoring()
        #expect(
            Set(requests.withLock { $0 }) == [
                "https://eurooilwatch.com/api/v1/stocks", "https://eurooilwatch.com/api/v1/history", "https://eurooilwatch.com/api/v1/prices"
            ])
        if failure == "all" {
            #expect(sensors.isEmpty == true)
        }
        else {
            let sensor = try #require(sensors.first)
            #expect(sensor.placemark == "EuroOilWatch · Eurostat")
            #expect((sensor.measurements[.energy(.petrolStock)] != nil) == (failure != "history"))
            #expect((sensor.measurements[.energy(.dieselStock)] != nil) == (failure != "stocks"))
            #expect((sensor.customData?["nationalPrices"] as? NationalFuelPrices != nil) == (failure != "prices"))
            #expect(sensor.forecasts.isEmpty == true)
        }
    }
}
