import DoomKitLocation
import Foundation
import Testing

@Suite struct CovidDistrictTests {
    /// A square feature from `south`-`west` with the side `size` in degrees, as the district service sends it in EPSG:4326.
    private static func square(ags: String, name: String, geofactor: Int, south: Double, west: Double, size: Double) -> String {
        let ring = [[west, south], [west + size, south], [west + size, south + size], [west, south + size], [west, south]]
        let coordinates = ring.map { "[\($0[0]),\($0[1])]" }.joined(separator: ",")
        return #"{"type":"Feature","properties":{"ags":"\#(ags)","gen":"\#(name)","gf":\#(geofactor)},"geometry":{"type":"Polygon","coordinates":[[\#(coordinates)]]}}"#
    }

    private static func response(_ features: [String]) -> Data {
        return Data(#"{"type":"FeatureCollection","features":[\#(features.joined(separator: ","))]}"#.utf8)
    }

    /// Dithmarschen's land east of 8.8°, its Wadden Sea west of it, and Steinburg to the south.
    private static let coast = Self.response([
        Self.square(ags: "01051", name: "Dithmarschen", geofactor: 4, south: 53.9, west: 8.8, size: 0.4),
        Self.square(ags: "01051", name: "Dithmarschen", geofactor: 2, south: 53.9, west: 8.4, size: 0.4),
        Self.square(ags: "01061", name: "Steinburg", geofactor: 4, south: 53.5, west: 8.8, size: 0.4)
    ])

    @Test func aPlaceIsInTheDistrictThatContainsIt() throws {
        let büsum = Location(latitude: 54.1283, longitude: 8.8589)
        let district = try #require(try CovidController.resolveDistrict(from: Self.coast, for: büsum))
        #expect(district.id == "01051")
        // The centroid is the land's, a place on the map, not the sea's.
        #expect(abs(district.location.latitude - 54.1) < 0.001 && abs(district.location.longitude - 9.0) < 0.001)
        let south = try #require(try CovidController.resolveDistrict(from: Self.coast, for: Location(latitude: 53.7, longitude: 9.0)))
        #expect(south.id == "01061")
    }

    @Test func aPlaceInTheSeaIsInTheNearestLand() throws {
        let wadden = Location(latitude: 54.1, longitude: 8.6)
        let district = try #require(try CovidController.resolveDistrict(from: Self.coast, for: wadden))
        #expect(district.id == "01051")
        #expect(district.polygons.count == 1)
        #expect(district.polygons.first?.allSatisfy { $0.longitude >= 8.8 } == true)
    }

    @Test func projectedCoordinatesAreNoDistrict() throws {
        // What the service answers without srsName: UTM zone 32 metres, which read as degrees lie off the globe.
        let projected = Self.response([
            #"{"type":"Feature","properties":{"ags":"01051","gen":"Dithmarschen","gf":4},"geometry":{"type":"Polygon","coordinates":[[[479673.0,5990236.3],[507169.5,5998530.6],[490964.4,5997384.0],[479673.0,5990236.3]]]}}"#
        ])
        #expect(try CovidController.resolveDistrict(from: projected, for: Location(latitude: 54.1283, longitude: 8.8589)) == nil)
    }
}
