import DoomKitLocation
import DoomKitNetwork
import DoomKitProcess
import Foundation
import Synchronization
import Testing

@Suite struct EnergyControllerTests {
    private actor Monitor: NetworkMonitoring {
        func start(_ receive: @escaping @Sendable (Bool, ConnectionType) -> Void) { receive(true, .wifi) }
        func stop() {}
    }

    /// EuroOilWatch's JSON shape, reversed to exercise sorting, with a duplicate and rows without a valid USD price or session.
    private static let brentHistory = """
        {"lastUpdated":"2026-10-24T19:47:17Z","entries":[
        {"date":"2026-10-23","priceUsd":116.72,"priceEur":104.17,"contract":"BZZ26.NYM"},
        {"date":"2026-10-22","priceUsd":113.17},
        {"date":"2026-10-22","priceUsd":113.17},
        {"date":"2026-10-21","priceUsd":null},
        {"date":"2026-10-20","priceUsd":-1},
        {"date":"2026-10-19","priceEur":99},
        {"date":"not a date","priceUsd":100},
        {"date":"2099-01-01","priceUsd":100}]}
        """

    private static let brentQuote = """
        {"fetchedAt":"2026-10-25T19:57:03Z","sessionDate":"2026-10-23","observedAt":"2026-10-23T20:59:44Z",
        "priceUsd":116.80,"priceEur":104.17,"contract":"BZZ26.NYM","contractLabel":"December 2026",
        "quoteType":"settled","quoteStatus":"last-available-close","staleReason":"previous session"}
        """

    /// ACER's export, verbatim: quoted, newest first, and the early rows have no EU price.
    private static let lng = """
        "DATE","NORTH-WEST EUROPE PRICE (EUR/MWh)","SOUTH EUROPE PRICE (EUR/MWh)","EU PRICE (EUR/MWh)","LNG BENCHMARK (EUR/MWh)"
        "2026-09-18","78.404","78.307","78.223","-1.295"
        "2026-09-17","80.669","79.728","80.073","3.721"
        "2023-01-27","54.770","53.080","",""
        """

    private static func utcMidnight(_ text: String) -> Date? {
        return EnergyController.date(from: text)
    }

    @Test func spotAndTTFKeepTheirOwnUnitsAndObservationDates() throws {
        let now = try #require(Self.utcMidnight("2026-10-25"))
        let spot = Data(
            #"{"lastUpdated":"2026-10-25T19:00:00Z","entries":[{"date":"2026-10-20","priceUsd":115.22},{"date":"2026-10-19","priceUsd":118.82},{"date":"2026-10-20","priceUsd":115.22},{"date":"2026-02-30","priceUsd":99}]}"#
                .utf8)
        let spotValues = EnergyController.parseBrentSpot(spot, now: now)
        #expect(spotValues.map { $0.value.value } == [118.82, 115.22])
        #expect(spotValues.last?.timestamp == Self.utcMidnight("2026-10-20"))
        #expect(spotValues.last?.value.unit == UnitOilPrice.usDollarsPerBarrel)
        let gas = Data(
            #"{"lastUpdated":"2026-10-25T19:00:00Z","ttf":{"priceEurMwh":999},"history":[{"date":"2026-10-23","ttfEurMwh":93.85,"hhUsdMmbtu":3.05},{"date":"2026-10-22","ttfEurMwh":90.04},{"date":"2099-01-01","ttfEurMwh":200},{"date":"2026-10-21","ttfEurMwh":null}]}"#
                .utf8)
        let ttfValues = EnergyController.parseTTF(gas, now: now)
        #expect(ttfValues.map { $0.value.value } == [90.04, 93.85])
        #expect(ttfValues.last?.timestamp == Self.utcMidnight("2026-10-23"))
        #expect(ttfValues.last?.value.unit == UnitGasPrice.eurosPerMegawattHour)
        #expect(EnergyController.parseTTF(Data(#"{"ttf":{"priceEurMwh":999}}"#.utf8)).isEmpty == true)
        // The tab's order: the prices, then the stocks in a section of their own.
        #expect(ProcessSelector.Energy.allCases == [.brentSpot, .brent, .ttf, .lng, .petrolStock, .dieselStock, .jetFuelStock])
        #expect(ProcessSelector.Energy.allCases.filter { $0.isStock == true } == [.petrolStock, .dieselStock, .jetFuelStock])
    }

    @Test func brentUsesFuturesHistoryAndReplacesTheLatestSessionWithTheQuote() throws {
        let now = try #require(Self.utcMidnight("2026-10-25"))
        let values = EnergyController.parseBrent(history: Data(Self.brentHistory.utf8), quote: Data(Self.brentQuote.utf8), now: now)
        #expect(values.map { $0.value.value } == [113.17, 116.80])
        #expect(values.allSatisfy { $0.value.unit == UnitOilPrice.usDollarsPerBarrel } == true)
        #expect(values.allSatisfy { $0.quality == .good } == true)
        let latest = try #require(values.last)
        #expect(latest.timestamp == Self.utcMidnight("2026-10-23"))
        #expect(latest.customData?["contract"] as? String == "BZZ26.NYM")
        #expect(latest.customData?["observedAt"] as? String == "2026-10-23T20:59:44Z")
        #expect(latest.customData?["quoteStatus"] as? String == "last-available-close")
        #expect(latest.customData?["staleReason"] as? String == "previous session")
    }

    @Test func brentEndpointsCanFailIndependentlyAndOlderQuotesCannotOverwriteHistory() throws {
        let now = try #require(Self.utcMidnight("2026-10-25"))
        let history = Data(Self.brentHistory.utf8)
        let quote = Data(Self.brentQuote.utf8)
        #expect(EnergyController.parseBrent(history: history, quote: nil, now: now).map { $0.value.value } == [113.17, 116.72])
        #expect(EnergyController.parseBrent(history: nil, quote: quote, now: now).map { $0.value.value } == [116.80])
        let older = Data(#"{"sessionDate":"2026-10-22","priceUsd":1}"#.utf8)
        #expect(EnergyController.parseBrent(history: history, quote: older, now: now).map { $0.value.value } == [113.17, 116.72])
        let newer = Data(#"{"sessionDate":"2026-10-24","priceUsd":117}"#.utf8)
        #expect(EnergyController.parseBrent(history: history, quote: newer, now: now).map { $0.value.value } == [113.17, 116.72, 117])
    }

    @Test(arguments: [
        "{}", "garbage", #"{"priceUsd":117,"fetchedAt":"2026-10-25T10:00:00Z"}"#,
        #"{"sessionDate":"2026-10-23","priceUsd":null}"#, #"{"sessionDate":"2026-10-23","priceUsd":0}"#,
        #"{"sessionDate":"2099-01-01","priceUsd":117}"#
    ])
    func invalidBrentQuotesLeaveTheHistoryIntact(text: String) throws {
        let now = try #require(Self.utcMidnight("2026-10-25"))
        let values = EnergyController.parseBrent(history: Data(Self.brentHistory.utf8), quote: Data(text.utf8), now: now)
        #expect(values.map { $0.value.value } == [113.17, 116.72])
    }

    @Test func lngRowsUseTheEUPriceAndSkipRowsWithout() throws {
        let data = try #require(Self.lng.data(using: .isoLatin1))
        let values = EnergyController.parseLNG(data)
        // Sorted oldest first whatever the file's order, and the 2023 row without an EU price is gone.
        #expect(values.map { $0.value.value } == [80.073, 78.223])
        #expect(values.allSatisfy { $0.value.unit == UnitGasPrice.eurosPerMegawattHour } == true)
        #expect(values.first?.timestamp == Self.utcMidnight("2026-09-17"))
    }

    @Test func datesAreMidnightUTC() throws {
        let date = try #require(Self.utcMidnight("2026-09-15"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        #expect(parts.year == 2026 && parts.month == 9 && parts.day == 15 && parts.hour == 0 && parts.minute == 0)
        // What the chart's drag rounding lands on, so a dragged marker finds the day.
        #expect(Date.round(from: date.addingTimeInterval(5 * 3600), strategy: .lastDayChange) == date)
    }

    @Test func unreadableRowsAreSkipped() {
        #expect(EnergyController.parseBrent(history: nil, quote: nil).isEmpty == true)
        #expect(EnergyController.parseBrent(history: Data("garbage".utf8), quote: Data("{}".utf8)).isEmpty == true)
        #expect(EnergyController.parseLNG(Data("garbage".utf8)).isEmpty == true)
    }

    @Test(arguments: ["none", "brent", "brent-history", "spot", "gas", "lng", "all"])
    func refreshKeepsIndependentSourcesAndRequestsEachEndpoint(failure: String) async throws {
        let requests = Mutex<[String]>([])
        // Dates are relative to now so this fixture stays inside the controller's one-year chart span.
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        let day = formatter.string(from: .now.addingTimeInterval(-24 * 3600))
        let network = NetworkManager(
            transport: { request in
                let url = try #require(request.url)
                requests.withLock { $0.append(url.absoluteString) }
                let failedComponent = failure == "spot" ? "brent-eia-daily" : failure
                if failure == "all" || url.lastPathComponent == failedComponent { throw URLError(.cancelled) }
                let text: String
                switch url.lastPathComponent {
                    case "brent": text = "{\"sessionDate\":\"\(day)\",\"priceUsd\":116.80}"
                    case "brent-history": text = "{\"entries\":[{\"date\":\"\(day)\",\"priceUsd\":116.72}]}"
                    case "brent-eia-daily": text = "{\"entries\":[{\"date\":\"\(day)\",\"priceUsd\":115.22}]}"
                    case "gas": text = "{\"history\":[{\"date\":\"\(day)\",\"ttfEurMwh\":93.85}]}"
                    case "stocks":
                        text =
                            "{\"countries\":[{\"countryCode\":\"DE\",\"fuels\":[{\"fuelType\":\"diesel\",\"daysOfSupply\":102.5,"
                            + "\"provenance\":{\"stockPeriod\":\"2026-07\",\"observation\":\"observed\"}}]}]}"
                    case "history":
                        text = "{\"countries\":[{\"countryCode\":\"DE\",\"data\":[{\"period\":\"2026-06\",\"petrolDays\":43.2}]}]}"
                    default:
                        if failure == "lng" { throw URLError(.cancelled) }
                        text = "DATE,NW,S,EU\n\(day),78,78,78.223"
                }
                let response = try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
                return (Data(text.utf8), response)
            }, makeMonitor: { Monitor() }, probeURL: nil)
        let updates = await network.updates()
        await network.startMonitoring()
        for await state in updates where state.isConnected == true { break }
        let sensors = try await EnergyController(networkManager: network, showForecasts: { false })
            .refreshData(for: Location(latitude: 52.51889, longitude: 13.36528))
        await network.stopMonitoring()
        #expect(
            Set(requests.withLock { $0 }) == [
                "https://eurooilwatch.com/api/v1/brent", "https://eurooilwatch.com/api/v1/brent-history",
                "https://eurooilwatch.com/api/v1/brent-eia-daily", "https://eurooilwatch.com/api/v1/gas",
                "https://aegis.acer.europa.eu/terminal/price_assessments/historical_data",
                "https://eurooilwatch.com/api/v1/stocks", "https://eurooilwatch.com/api/v1/history"
            ])
        if failure == "all" {
            #expect(sensors.isEmpty == true)
        }
        else {
            let sensor = try #require(sensors.first)
            #expect(sensor.placemark == "EuroOilWatch · ACER")
            #expect(sensor.measurements[.energy(.brent)]?.last?.value.value == (failure == "brent" ? 116.72 : 116.80))
            #expect((sensor.measurements[.energy(.lng)] != nil) == (failure != "lng"))
            #expect((sensor.measurements[.energy(.brentSpot)] != nil) == (failure != "spot"))
            #expect((sensor.measurements[.energy(.ttf)] != nil) == (failure != "gas"))
            // The stocks come from their own endpoints, so a failed price endpoint does not cost them.
            #expect(sensor.measurements[.energy(.petrolStock)]?.last?.value.value == 43.2)
            #expect(sensor.measurements[.energy(.dieselStock)]?.last?.value.value == 102.5)
            #expect(sensor.forecasts.isEmpty == true)
        }
    }

    @Test func theSeriesFillsClosedDaysAndKeepsOnlyTheSpan() throws {
        // Friday, then the next Monday: the weekend has no prices.
        let friday = try #require(Self.utcMidnight("2026-09-11"))
        let monday = try #require(Self.utcMidnight("2026-09-14"))
        let old = try #require(Self.utcMidnight("2025-01-05"))
        let value = { (price: Double, date: Date) in
            return ProcessValue<Dimension>(
                value: Measurement(value: price, unit: UnitOilPrice.usDollarsPerBarrel), quality: .good, timestamp: date)
        }
        let now = monday.addingTimeInterval(36 * 3600)
        let series = EnergyController.series([value(1, old), value(118, friday), value(121, monday)], until: now)
        #expect(series.map { $0.value.value } == [118, 118, 118, 121])
        #expect(series.map { $0.quality } == [.good, .uncertain, .uncertain, .good])
        #expect(series.first?.timestamp == friday)
        #expect(series.last?.timestamp == monday)
        #expect(series[1].timestamp == friday.addingTimeInterval(24 * 3600))
        // The old price is outside the year and gone; nothing at all gives nothing.
        #expect(EnergyController.series([value(1, old)], until: now).isEmpty == true)
        #expect(EnergyController.series([], until: now).isEmpty == true)
    }

    @Test func thePricesOfAYearFitTheChartWithRoom() throws {
        let transformer = EnergyTransformer()
        let date = try #require(Self.utcMidnight("2026-09-15"))
        let values = [100.0, 120.0].map { price in
            return ProcessValue<Dimension>(
                value: Measurement(value: price, unit: UnitOilPrice.usDollarsPerBarrel), quality: .good, timestamp: date)
        }
        let range = try #require(transformer.renderRange(measurements: [.energy(.brent): values])[.energy(.brent)])
        #expect(abs(range.lowerBound - 98) < 0.001)
        #expect(abs(range.upperBound - 122.4) < 0.001)
        let faceplate = transformer.renderFaceplate(current: [.energy(.brent): values[1]])
        #expect(faceplate[.energy(.brent)] == "120.00 USD/bbl")
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
        let series = EnergyController.parseStockHistory(Data(Self.stockHistory.utf8))
        let petrol = try #require(series[.petrolStock])
        #expect(petrol.map { $0.value.value } == [54.1, 57.8])
        let july = try #require(Self.utcMidnight("2026-07-31"))
        let august = try #require(Self.utcMidnight("2026-08-31"))
        #expect(petrol.map { $0.timestamp } == [july, august])
        #expect(petrol.allSatisfy { $0.value.unit == UnitSupplyDays.days } == true)
        #expect(petrol.first?.customData?["period"] as? String == "2026-07")
        #expect(series[.dieselStock]?.last?.value.value == 119.3)
        #expect(series[.jetFuelStock]?.count == 2)
        #expect(EnergyController.parseStockHistory(Data(Self.stockHistory.utf8), country: "FR").isEmpty == true)
        #expect(EnergyController.parseStockHistory(Data("not json".utf8)).isEmpty == true)
    }

    @Test func theLatestStockIsUncertainUnlessObservedAndCarriesItsTonnes() throws {
        let latest = EnergyController.parseLatestStocks(Data(Self.latestStocks.utf8))
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
        let history = EnergyController.parseStockHistory(Data(Self.stockHistory.utf8))
        let latest = EnergyController.parseLatestStocks(Data(Self.latestStocks.utf8))
        let series = EnergyController.stockSeries(history: history, latest: latest)
        // July comes from the latest endpoint, uncertain, and August stays: the history can be a month ahead.
        let diesel = try #require(series[.dieselStock])
        #expect(diesel.map { $0.value.value } == [102.5, 119.3])
        #expect(diesel.map { $0.quality } == [.uncertain, .good])
        let june = try #require(Self.utcMidnight("2026-06-30"))
        let older = ProcessValue<Dimension>(value: Measurement(value: 1, unit: UnitSupplyDays.days), quality: .good, timestamp: june)
        let newer = EnergyController.stockSeries(history: [.jetFuelStock: [older]], latest: [.jetFuelStock: try #require(latest[.petrolStock])])
        let july = try #require(Self.utcMidnight("2026-07-31"))
        #expect(newer[.jetFuelStock]?.map { $0.timestamp } == [june, july])
    }

    @Test func aMonthEndsOnItsLastDayAndOnlyMonthsParse() {
        #expect(EnergyController.monthEnd(from: "2028-02") == Self.utcMidnight("2028-02-29"))
        #expect(EnergyController.monthEnd(from: "2026-12") == Self.utcMidnight("2026-12-31"))
        #expect(EnergyController.monthEnd(from: "2026-13") == nil)
        #expect(EnergyController.monthEnd(from: "2026-7") == nil)
        #expect(EnergyController.monthEnd(from: "2026-07-01") == nil)
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
        let last = try #require(EnergyController.monthEnd(from: lastMonth))
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
        let forecast = try #require(EnergyController.stockEstimate(from: values, now: now))
        #expect(forecast.origin.isProvider == false)
        #expect(forecast.points.last?.timestamp == now)
        #expect(forecast.points.allSatisfy { $0.timestamp > last.timestamp && $0.timestamp <= now } == true)
        // One month on the grid before today: the end of September.
        #expect(forecast.points.count == 2)
        #expect(forecast.points.allSatisfy { $0.value.value >= 0 } == true)
        // Nothing before the last report, and nothing when the reports stopped half a year ago.
        #expect(EnergyController.stockEstimate(from: values, now: last.timestamp) == nil)
        #expect(EnergyController.stockEstimate(from: values, now: last.timestamp.addingTimeInterval(200 * 24 * 3600)) == nil)
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
        let cut = try #require(EnergyController.ending(forecast, at: start.addingTimeInterval(45 * day), from: last))
        #expect(cut.points.count == 2)
        #expect(cut.points[1].value.value == 70)
        #expect(cut.points[1].lower == 60)
        #expect(cut.points[1].upper == 80)
        // Before the first point the last measurement is the neighbour, without a band of its own.
        let early = try #require(EnergyController.ending(forecast, at: start.addingTimeInterval(15 * day), from: last))
        #expect(early.points.count == 1)
        #expect(early.points[0].value.value == 55)
        #expect(early.points[0].lower == 50)
        #expect(EnergyController.ending(forecast, at: start.addingTimeInterval(90 * day), from: last) == nil)
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
}
