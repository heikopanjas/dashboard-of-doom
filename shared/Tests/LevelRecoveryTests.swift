import DoomKitLocation
import DoomKitNetwork
import Foundation
import Testing

@Suite struct LevelRecoveryTests {
    private actor Monitor: NetworkMonitoring {
        func start(_ receive: @escaping @Sendable (Bool, ConnectionType) -> Void) { receive(true, .wifi) }
        func stop() {}
    }

    @Test(arguments: [503, 200])
    func unavailableOrEmptyWaterwaysKeepOfficialGauge(status: Int) async throws {
        let network = NetworkManager(
            transport: { request in
                let url = try #require(request.url)
                let isGauge = url.host == "www.pegelonline.wsv.de"
                let data = isGauge
                    ? Data(#"[{"uuid":"near","latitude":52.52,"longitude":13.37,"water":{"longname":"SPREE"}},{"uuid":"far","latitude":53.5,"longitude":14.0,"water":{"longname":"ODER"}}]"#.utf8)
                    : Data(#"{"elements":[]}"#.utf8)
                let response = try #require(HTTPURLResponse(url: url, statusCode: isGauge ? 200 : status, httpVersion: nil, headerFields: nil))
                return (data, response)
            }, makeMonitor: { Monitor() }, probeURL: nil)
        await network.startMonitoring()
        try await network.waitForConnection(timeout: .seconds(2))
        let controller = LevelController(networkManager: network, nearestSensor: { false })
        // An explicit limit: the default is the platform's sensor cap, which is 1 on macOS.
        let stations = try await controller.fetchNearestStations(location: Location(latitude: 52.51889, longitude: 13.36528), limit: 3)
        #expect(stations.map { $0.id } == ["near", "far"])
        // The waterway is re-cased; the gauge is not, because the header re-cases that one. This fixture has no gauge name of its own, so
        // the gauge falls back to the waterway and the two differ only in casing.
        #expect(stations.first?.waterway == "Spree")
        #expect(stations.first?.gauge == "SPREE")
        await network.stopMonitoring()
    }

    @Test func theSensorIsNamedAfterItsGaugeAndCarriesTheWaterway() async throws {
        let network = NetworkManager(
            transport: { request in
                let url = try #require(request.url)
                let response = try #require(HTTPURLResponse(url: url, statusCode: 503, httpVersion: nil, headerFields: nil))
                return (Data(), response)
            }, makeMonitor: { Monitor() }, probeURL: nil)
        await network.startMonitoring()
        try await network.waitForConnection(timeout: .seconds(2))
        let controller = LevelController(networkManager: network)
        let station = LevelController.Station(
            id: "id", waterway: "Spree", gauge: "BERLIN-MÜHLENDAMM UP", location: Location(latitude: 52.5, longitude: 13.4))
        let candidate = try await controller.candidate(for: station)
        // Level is named after its gauge like every other source is named after its station. The waterway does not fit the standard
        // interface, so it travels in customData, where the chart title reads it.
        #expect(candidate.name == "BERLIN-MÜHLENDAMM UP")
        #expect(candidate.customData["waterway"] as? String == "Spree")
        #expect(candidate.customData["station"] == nil)
        await network.stopMonitoring()
    }
}
