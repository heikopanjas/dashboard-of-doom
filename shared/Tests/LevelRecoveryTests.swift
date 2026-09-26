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
        // The marks request failed with the rest, and the gauge is kept without them.
        #expect(candidate.customData["marks"] == nil)
        await network.stopMonitoring()
    }

    @Test func theGaugesFloodMarksTravelInCustomDataInMetres() async throws {
        let characteristics = #"{"uuid":"id","timeseries":[{"shortname":"Q","characteristicValues":[{"shortname":"MQ","value":50.0}]},{"shortname":"W","unit":"cm","characteristicValues":[{"shortname":"MHW","value":412.0},{"shortname":"M_I","value":300.0},{"shortname":"HSW","value":310.0}]}]}"#
        let network = NetworkManager(
            transport: { request in
                let url = try #require(request.url)
                let isMarks = url.absoluteString.contains("includeCharacteristicValues=true")
                let response = try #require(HTTPURLResponse(url: url, statusCode: isMarks ? 200 : 503, httpVersion: nil, headerFields: nil))
                return (isMarks ? Data(characteristics.utf8) : Data(), response)
            }, makeMonitor: { Monitor() }, probeURL: nil)
        await network.startMonitoring()
        try await network.waitForConnection(timeout: .seconds(2))
        let controller = LevelController(networkManager: network)
        let station = LevelController.Station(id: "id", waterway: "Aller", gauge: "CELLE", location: Location(latitude: 52.6, longitude: 10.1))
        let candidate = try await controller.candidate(for: station)
        let marks = try #require(candidate.customData["marks"] as? [String: Double])
        // Only the W series counts: the discharge series' MQ is not a level.
        #expect(marks == ["MHW": 4.12, "M_I": 3.0, "HSW": 3.1])
        await network.stopMonitoring()
    }

    @Test func aStationWithoutMarksParsesToNothing() {
        #expect(LevelController.parseMarks(data: Data(#"{"timeseries":[{"shortname":"W"}]}"#.utf8)) == nil)
        #expect(LevelController.parseMarks(data: Data(#"{"timeseries":[{"shortname":"W","characteristicValues":[]}]}"#.utf8)) == [:])
        #expect(LevelController.parseMarks(data: Data("not json".utf8)) == nil)
    }
}
