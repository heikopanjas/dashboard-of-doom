import DoomKitLocation
import DoomKitProcess
import Foundation
import SwiftUI
import Testing

@MainActor
@Suite struct CovidMapViewTests {
    private let ring = [
        Location(latitude: 52.50, longitude: 13.35), Location(latitude: 52.55, longitude: 13.35),
        Location(latitude: 52.55, longitude: 13.42), Location(latitude: 52.50, longitude: 13.42),
    ]

    private func reading(polygons: [[Location]]?, faceplate: [ProcessSelector: String] = [.covid(.incidence): "Ο: 142.7"]) -> ProcessReading {
        var customData: [String: Any] = ["name": "COVID-19", "icon": "facemask"]
        if let polygons = polygons {
            customData["polygons"] = polygons
        }
        let sensor = ProcessSensor(
            name: "Berlin Mitte", location: Location(latitude: 52.52, longitude: 13.38), placemark: "Heidestraße", customData: customData,
            measurements: [:], timestamp: nil)
        return ProcessReading(sensor: sensor, faceplate: faceplate)
    }

    @Test func oneLabelSitsAtTheDistrictCentroid() throws {
        let annotations = CovidMapView.annotations(covid: [self.reading(polygons: [self.ring])])
        // COVID reports exactly one district, so exactly one label.
        #expect(annotations.count == 1)
        let annotation = try #require(annotations.first)
        #expect(annotation.location == Location(latitude: 52.52, longitude: 13.38))
        #expect(annotation.icon == "facemask")
        #expect(annotation.faceplate == "Ο: 142.7")
        #expect(annotation.displayColor == Color.covid)
        #expect(annotation.showsLabel == true)
    }

    @Test func theLabelKeepsAFixedIdAcrossRefreshes() {
        // ProcessReading.id changes on every refresh, since the COVID sensor carries no sourceID. Keying the label on it would move its
        // placement each time, so the id is fixed.
        let first = CovidMapView.annotations(covid: [self.reading(polygons: [self.ring])])
        let second = CovidMapView.annotations(covid: [self.reading(polygons: [self.ring])])
        #expect(first.map { $0.id } == ["covid"])
        #expect(first.map { $0.id } == second.map { $0.id })
    }

    @Test func theOutlineComesBackOutOfCustomData() {
        let polygons = CovidMapView.polygons(covid: [self.reading(polygons: [self.ring])])
        #expect(polygons.count == 1)
        #expect(polygons.first == self.ring)
    }

    @Test func aMultiPolygonDistrictKeepsEveryRing() {
        // A Kreis with an exclave arrives as several outer rings, and all of them are drawn.
        let second = self.ring.map { Location(latitude: $0.latitude + 0.2, longitude: $0.longitude) }
        let polygons = CovidMapView.polygons(covid: [self.reading(polygons: [self.ring, second])])
        #expect(polygons.count == 2)
        #expect(polygons.last == second)
    }

    @Test func aDistrictWithoutAnOutlineDrawsNoShape() {
        // The cast must fail softly: a sensor from any other source has no polygons at all.
        #expect(CovidMapView.polygons(covid: [self.reading(polygons: nil)]).isEmpty == true)
    }

    @Test func noDistrictMeansNoMap() {
        #expect(CovidMapView.annotations(covid: []).isEmpty == true)
        #expect(CovidMapView.polygons(covid: []).isEmpty == true)
    }
}
