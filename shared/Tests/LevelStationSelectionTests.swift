import DoomKitLocation
import Foundation
import Testing

@Suite struct LevelStationSelectionTests {
    private static let user = Location(latitude: 52.5, longitude: 13.4)

    /// A gauge `north` degrees of latitude from the user, so a larger value is further away.
    private static func station(_ id: String, _ waterway: String, north: Double) -> LevelController.Station {
        return LevelController.Station(id: id, name: waterway, gauge: id, location: Location(latitude: 52.5 + north, longitude: 13.4))
    }

    private static func ids(_ stations: [LevelController.Station]) -> [String] {
        return stations.map { $0.id }
    }

    @Test func waterwayGaugesComeNearestFirstAndCappedAtThree() {
        let stations = [
            Self.station("s0", "SPREE", north: 0.06), Self.station("s1", "SPREE", north: 0.01), Self.station("s2", "SPREE", north: 0.05),
            Self.station("s3", "SPREE", north: 0.02), Self.station("s4", "SPREE", north: 0.04), Self.station("s5", "SPREE", north: 0.03),
            Self.station("havel", "HAVEL", north: 0.005)
        ]
        let selected = LevelController.selectStations(from: stations, near: Self.user, waterwayName: "Spree", limit: 3)
        // The Havel gauge is nearest overall but is not on the Spree; the two furthest Spree gauges are past the cap.
        #expect(Self.ids(selected) == ["s1", "s3", "s5"])
    }

    @Test func shortWaterwayIsNotPaddedWithOtherRivers() {
        let stations = [
            Self.station("b", "SPREE", north: 0.02), Self.station("a", "SPREE", north: 0.01), Self.station("havel", "HAVEL", north: 0.005)
        ]
        let selected = LevelController.selectStations(from: stations, near: Self.user, waterwayName: "SPREE", limit: 3)
        #expect(Self.ids(selected) == ["a", "b"])
    }

    @Test(arguments: [nil, "Elbe"] as [String?])
    func withoutAMatchingWaterwayTheNearestGaugesOverallAreUsed(waterwayName: String?) {
        let stations = (0 ..< 7).map { Self.station("g\($0)", $0 % 2 == 0 ? "SPREE" : "HAVEL", north: Double(7 - $0) * 0.01) }
        let selected = LevelController.selectStations(from: stations, near: Self.user, waterwayName: waterwayName, limit: 3)
        #expect(Self.ids(selected) == ["g6", "g5", "g4"])
    }

    @Test func gaugesBeyondAThousandKilometresAreIgnored() {
        let stations = [Self.station("abroad", "DANUBE", north: 12.5), Self.station("home", "SPREE", north: 0.01)]
        #expect(Self.ids(LevelController.selectStations(from: stations, near: Self.user, waterwayName: nil, limit: 3)) == ["home"])
        #expect(LevelController.selectStations(from: [stations[0]], near: Self.user, waterwayName: nil, limit: 3).isEmpty == true)
    }

    @Test func noGaugesSelectsNothing() {
        #expect(LevelController.selectStations(from: [], near: Self.user, waterwayName: "Spree", limit: 3).isEmpty == true)
    }

    /// Two Spree gauges, and gauges on the Havel and a canal that are nearer than either.
    private static let mixed = [
        station("s1", "SPREE", north: 0.02), station("s2", "SPREE", north: 0.04), station("h1", "HAVEL", north: 0.005),
        station("l1", "LANDWEHRKANAL", north: 0.01), station("h2", "HAVEL", north: 0.03)
    ]

    @Test func otherWaterwaysKeepTheFirstOnTheWaterwayAndTakeTheNearestOthers() {
        let selected = LevelController.selectStations(from: Self.mixed, near: Self.user, waterwayName: "Spree", limit: 3, otherWaterways: true)
        // The first follows the usual rule. The extras are the nearest remaining gauges, and both are nearer than the first.
        #expect(Self.ids(selected) == ["s1", "h1", "l1"])
    }

    @Test func withoutTheSettingTheExtrasStayOnTheSameWaterway() {
        #expect(Self.ids(LevelController.selectStations(from: Self.mixed, near: Self.user, waterwayName: "Spree", limit: 3)) == ["s1", "s2"])
        let off = LevelController.selectStations(from: Self.mixed, near: Self.user, waterwayName: "Spree", limit: 3, otherWaterways: false)
        #expect(Self.ids(off) == ["s1", "s2"])
    }

    @Test func aLimitOfOneIgnoresTheSetting() {
        let selected = LevelController.selectStations(from: Self.mixed, near: Self.user, waterwayName: "Spree", limit: 1, otherWaterways: true)
        #expect(Self.ids(selected) == ["s1"])
    }

    @Test(arguments: [nil, "Elbe"] as [String?])
    func withoutAMatchingWaterwayTheFirstIsTheNearestAndTheExtrasFollow(waterwayName: String?) {
        let selected = LevelController.selectStations(from: Self.mixed, near: Self.user, waterwayName: waterwayName, limit: 3, otherWaterways: true)
        #expect(Self.ids(selected) == ["h1", "l1", "s1"])
    }

    @Test func theFirstGaugeIsNeverRepeatedAmongTheExtras() {
        let selected = LevelController.selectStations(from: Self.mixed, near: Self.user, waterwayName: "Spree", limit: 5, otherWaterways: true)
        #expect(Self.ids(selected) == ["s1", "h1", "l1", "h2", "s2"])
        #expect(Set(Self.ids(selected)).count == selected.count)
    }

    @Test func fewerGaugesThanTheLimitAreAllReported() {
        let two = [Self.mixed[0], Self.mixed[2]]
        #expect(Self.ids(LevelController.selectStations(from: two, near: Self.user, waterwayName: "Spree", limit: 3, otherWaterways: true)) == ["s1", "h1"])
        #expect(LevelController.selectStations(from: [], near: Self.user, waterwayName: "Spree", limit: 3, otherWaterways: true).isEmpty == true)
    }

    @Test func extraGaugesBeyondAThousandKilometresAreIgnored() {
        let stations = [Self.station("s1", "SPREE", north: 0.02), Self.station("abroad", "DANUBE", north: 12.5)]
        let selected = LevelController.selectStations(from: stations, near: Self.user, waterwayName: "Spree", limit: 3, otherWaterways: true)
        #expect(Self.ids(selected) == ["s1"])
    }
}
