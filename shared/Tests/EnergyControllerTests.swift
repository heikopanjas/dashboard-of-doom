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
        #expect(ProcessSelector.Energy.allCases == [.brentSpot, .brent, .ttf, .lng])
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
    func refreshKeepsIndependentSourcesAndRequestsOnlyBrentAndLNG(failure: String) async throws {
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
                "https://aegis.acer.europa.eu/terminal/price_assessments/historical_data"
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
}
