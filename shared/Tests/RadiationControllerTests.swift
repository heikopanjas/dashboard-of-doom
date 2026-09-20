import DoomKitLocation
import Foundation
import Testing

@Suite struct RadiationControllerTests {
    private static let user = Location(latitude: 52.5, longitude: 13.4)

    /// A station `north` degrees of latitude from the user, so a larger value is further away.
    private static func station(_ id: String, north: Double) -> RadiationController.Station {
        return RadiationController.Station(id: id, name: "Station \(id)", location: Location(latitude: 52.5 + north, longitude: 13.4))
    }

    private static let stations = [
        station("d", north: 0.04), station("a", north: 0.01), station("c", north: 0.03), station("b", north: 0.02), station("e", north: 0.05)
    ]

    private static func ids(_ stations: [RadiationController.Station]) -> [String] {
        return stations.map { $0.id }
    }

    @Test(arguments: [1, 2, 3])
    func theNearestStationsComeFirstUpToTheLimit(limit: Int) {
        let selected = RadiationController.nearestStations(stations: Self.stations, location: Self.user, limit: limit)
        #expect(Self.ids(selected) == Array(["a", "b", "c"].prefix(limit)))
    }

    @Test func fewerStationsThanTheLimitAreAllReported() {
        let two = Array(Self.stations.prefix(2))
        #expect(Self.ids(RadiationController.nearestStations(stations: two, location: Self.user, limit: 3)) == ["a", "d"])
        #expect(RadiationController.nearestStations(stations: [], location: Self.user, limit: 3).isEmpty == true)
    }
}
