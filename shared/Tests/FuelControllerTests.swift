import DoomKitLocation
import DoomKitNetwork
import Foundation
import Synchronization
import Testing

@Suite struct FuelControllerTests {
    private actor Monitor: NetworkMonitoring {
        func start(_ receive: @escaping @Sendable (Bool, ConnectionType) -> Void) { receive(true, .wifi) }
        func stop() {}
    }

    /// The shape Tankerkoenig really answers with, trimmed to three stations.
    private static let response = """
        {"ok":true,"license":"CC BY 4.0 -  https://creativecommons.tankerkoenig.de","data":"MTS-K","status":"ok","stations":[
        {"id":"474e5046-deaf-4f9b-9a32-9797b778f047","name":"TotalEnergies Berlin","brand":"TotalEnergies","street":"Margarete-Sommer-Str.",
        "place":"Berlin","lat":52.530831,"lng":13.440946,"dist":1.1,"diesel":2.419,"e5":2.319,"e10":2.259,"isOpen":false,
        "houseNumber":"2","postCode":10407},
        {"id":"aaaa","name":"Aral Tankstelle","brand":"ARAL","street":"Storkower Str.","place":"Berlin","lat":52.5,"lng":13.4,
        "dist":2.4,"diesel":2.399,"e5":2.349,"e10":null,"isOpen":true,"houseNumber":"140","postCode":10407},
        {"id":"bbbb","name":"Keine Preise","brand":"","street":"Nowhere","place":"Berlin","lat":52.5,"lng":13.4,"dist":3.0,
        "diesel":null,"e5":null,"e10":null,"isOpen":true,"houseNumber":"","postCode":10407}]}
        """

    @Test func stationsAreReadWithEveryFuelTheySell() throws {
        let stations = try FuelController.parseStations(from: Data(Self.response.utf8))
        // The third station sells nothing and is dropped.
        #expect(stations.map { $0.id } == ["474e5046-deaf-4f9b-9a32-9797b778f047", "aaaa"])
        let total = try #require(stations.first)
        #expect(total.name == "TotalEnergies Berlin")
        #expect(total.brand == "TotalEnergies")
        #expect(total.address == "Margarete-Sommer-Str. 2")
        #expect(total.distance == 1.1)
        #expect(total.location == Location(latitude: 52.530831, longitude: 13.440946))
        #expect(total.isOpen == false)
        #expect(total.price(for: .e5) == 2.319)
        #expect(total.price(for: .e10) == 2.259)
        #expect(total.price(for: .diesel) == 2.419)
        // A null price means the station does not sell that fuel.
        let aral = stations[1]
        #expect(aral.price(for: .e10) == nil)
        #expect(aral.price(for: .e5) == 2.349)
        #expect(aral.isOpen == true)
    }

    @Test func aRefusedRequestYieldsNothing() throws {
        // What the API answers when the parameters are wrong, rather than a station list.
        let refused = #"{"status":"error","ok":false,"message":"wenn type = all ist, muss sort 'dist' sein"}"#
        #expect(try FuelController.parseStations(from: Data(refused.utf8)).isEmpty == true)
        #expect(try FuelController.parseStations(from: Data(#"{"ok":true,"status":"ok"}"#.utf8)).isEmpty == true)
    }

    @Test func rowsWithoutAnIdPriceOrPlaceAreSkipped() throws {
        // No id, no price at all, and no coordinates: none of the three can go on the map.
        let partial = """
            {"ok":true,"stations":[{"name":"No id","lat":52.5,"lng":13.4,"e5":2.0},
            {"id":"x","name":"Zero","lat":52.5,"lng":13.4,"e5":0,"diesel":0},
            {"id":"y","name":"Nowhere","e5":2.0}]}
            """
        #expect(try FuelController.parseStations(from: Data(partial.utf8)).isEmpty == true)
    }

    @Test func withoutAKeyNothingIsRequested() async throws {
        let requests = Mutex(0)
        let network = NetworkManager(
            transport: { request in
                requests.withLock { $0 += 1 }
                let url = try #require(request.url)
                let response = try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
                return (Data("{}".utf8), response)
            }, makeMonitor: { Monitor() }, probeURL: nil)
        await network.startMonitoring()
        let location = Location(latitude: 52.52, longitude: 13.405)
        #expect(try await FuelController(networkManager: network, apiKey: { nil }).fetchStations(location: location).isEmpty == true)
        #expect(try await FuelController(networkManager: network, apiKey: { "" }).fetchStations(location: location).isEmpty == true)
        #expect(requests.withLock { $0 } == 0)
        await network.stopMonitoring()
    }
}
