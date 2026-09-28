import DoomKitLocation
import DoomKitNetwork
import DoomKitProcess
import Foundation
import Testing

@Suite struct LevelForecastTests {
    private actor Monitor: NetworkMonitoring {
        func start(_ receive: @escaping @Sendable (Bool, ConnectionType) -> Void) { receive(true, .wifi) }
        func stop() {}
    }

    private final class Requests: @unchecked Sendable {
        private let lock = NSLock()
        private var urls: [String] = []

        var all: [String] {
            self.lock.lock()
            defer { self.lock.unlock() }
            return self.urls
        }

        func record(_ url: String) {
            self.lock.lock()
            self.urls.append(url)
            self.lock.unlock()
        }
    }

    /// An Oder gauge's forecast run as PEGELONLINE sends it: two forecast values with percentiles and a later estimate without.
    private static let forecast = #"""
        [{"initialized":"2026-09-28T13:00:00+02:00","timestamp":"2026-09-28T14:00:00+02:00","value":102.0,"percentile10":100.0,"percentile90":105.0,"type":"forecast"},
         {"initialized":"2026-09-28T13:00:00+02:00","timestamp":"2026-09-28T15:00:00+02:00","value":103.0,"percentile10":100.0,"percentile90":107.0,"type":"forecast"},
         {"initialized":"2026-09-28T13:00:00+02:00","timestamp":"2026-09-28T17:00:00+02:00","value":104.0,"type":"estimate"}]
        """#

    private static func characteristics(forecast: Bool) -> String {
        let wv = forecast ? #",{"shortname":"WV","longname":"WASSERSTANDVORHERSAGE","unit":"cm","equidistance":60}"# : ""
        return #"{"uuid":"id","timeseries":[{"shortname":"W","unit":"cm","characteristicValues":[{"shortname":"MHW","value":412.0}]}"# + wv + "]}"
    }

    private static func date(_ string: String) -> Date? {
        return ISO8601DateFormatter().date(from: string)
    }

    /// A controller whose network answers the characteristics with or without a forecast, the forecast with `forecastBody`, and
    /// everything else with an empty list, recording every URL it was asked for. Every answer is a 200: the network retries anything
    /// else with a backoff of half a minute.
    private static func controller(
        hasForecast: Bool, forecastBody: String = LevelForecastTests.forecast, showForecasts: Bool = true, requests: Requests
    ) async throws -> (LevelController, NetworkManager) {
        let network = NetworkManager(
            transport: { request in
                let url = try #require(request.url)
                requests.record(url.absoluteString)
                let isCharacteristics = url.absoluteString.contains("includeCharacteristicValues=true")
                let isForecast = url.path.hasSuffix("/WV/measurements.json")
                let body = isCharacteristics ? Self.characteristics(forecast: hasForecast) : isForecast ? forecastBody : "[]"
                let response = try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
                return (Data(body.utf8), response)
            }, makeMonitor: { Monitor() }, probeURL: nil)
        await network.startMonitoring()
        try await network.waitForConnection(timeout: .seconds(2))
        return (LevelController(networkManager: network, showForecasts: { showForecasts }), network)
    }

    private static let station = LevelController.Station(
        id: "id", waterway: "Oder", gauge: "FRANKFURT1 (ODER)", location: Location(latitude: 52.35, longitude: 14.55))

    @Test func aForecastRunParsesIntoAProviderForecastInMetres() throws {
        let forecast = try #require(LevelController.parseForecast(data: Data(Self.forecast.utf8)))
        #expect(forecast.origin == .provider("PEGELONLINE"))
        #expect(forecast.issued == Self.date("2026-09-28T13:00:00+02:00"))
        #expect(forecast.points.map(\.value.value) == [1.02, 1.03, 1.04])
        #expect(forecast.points.first?.value.unit == UnitLength.meters)
        // The percentiles are the band; the estimate has none, so its point has no band.
        #expect(forecast.points.first?.lower == 1.0)
        #expect(forecast.points.first?.upper == 1.05)
        #expect(forecast.points.last?.hasBand == false)
        #expect(forecast.customData?["estimateFrom"] as? Date == Self.date("2026-09-28T17:00:00+02:00"))
    }

    @Test func somethingThatIsNotAForecastParsesToNothing() {
        #expect(LevelController.parseForecast(data: Data("[]".utf8)) == nil)
        #expect(LevelController.parseForecast(data: Data(#"{"status":404}"#.utf8)) == nil)
    }

    @Test func onlyAGaugeThatListsAForecastHasOne() {
        #expect(LevelController.hasForecast(data: Data(Self.characteristics(forecast: true).utf8)) == true)
        #expect(LevelController.hasForecast(data: Data(Self.characteristics(forecast: false).utf8)) == false)
        #expect(LevelController.hasForecast(data: Data("[]".utf8)) == false)
    }

    @Test func aGaugeWithAForecastCarriesItBesideItsSeries() async throws {
        let requests = Requests()
        let (controller, network) = try await Self.controller(hasForecast: true, requests: requests)
        let candidate = try await controller.candidate(for: Self.station)
        let forecast = try #require(candidate.forecasts[.water(.level)])
        #expect(forecast.origin.isProvider == true)
        #expect(forecast.points.count == 3)
        // The marks come from the same request that says there is a forecast.
        #expect(candidate.customData["marks"] as? [String: Double] == ["MHW": 4.12])
        #expect(requests.all.contains { $0.contains("includeForecastTimeseries=true") } == true)
        await network.stopMonitoring()
    }

    @Test func aGaugeWithoutAForecastIsNotAskedForOne() async throws {
        let requests = Requests()
        let (controller, network) = try await Self.controller(hasForecast: false, requests: requests)
        let candidate = try await controller.candidate(for: Self.station)
        #expect(candidate.forecasts.isEmpty == true)
        #expect(requests.all.contains { $0.contains("/WV/") } == false)
        await network.stopMonitoring()
    }

    @Test func withForecastsSwitchedOffNothingIsAskedFor() async throws {
        let requests = Requests()
        let (controller, network) = try await Self.controller(hasForecast: true, showForecasts: false, requests: requests)
        let candidate = try await controller.candidate(for: Self.station)
        #expect(candidate.forecasts.isEmpty == true)
        // The characteristics request goes out as before, without asking which series forecast.
        #expect(requests.all.contains { $0.contains("includeForecastTimeseries") } == false)
        #expect(requests.all.contains { $0.contains("/WV/") } == false)
        #expect(candidate.customData["marks"] as? [String: Double] == ["MHW": 4.12])
        await network.stopMonitoring()
    }

    @Test func aFailedForecastCostsOnlyTheForecast() async throws {
        let requests = Requests()
        // What a gauge answers when its forecast run has gone: an error object, not a list.
        let (controller, network) = try await Self.controller(hasForecast: true, forecastBody: #"{"status":404}"#, requests: requests)
        let candidate = try await controller.candidate(for: Self.station)
        #expect(candidate.forecasts.isEmpty == true)
        #expect(candidate.customData["marks"] as? [String: Double] == ["MHW": 4.12])
        #expect(candidate.name == "FRANKFURT1 (ODER)")
        await network.stopMonitoring()
    }
}
