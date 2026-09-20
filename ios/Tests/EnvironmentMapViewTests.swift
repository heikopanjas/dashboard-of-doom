import DoomKitLocation
import DoomKitProcess
import Foundation
import MapKit
import SwiftUI
import Testing

@MainActor
@Suite struct EnvironmentMapViewTests {
    private func reading(id: String?, icon: String? = "atom", faceplate: [ProcessSelector: String] = [:], north: Double = 0) -> ProcessReading {
        var customData: [String: Any]? = nil
        if let icon = icon {
            customData = ["icon": icon]
        }
        let sensor = ProcessSensor(
            name: "Name", location: Location(latitude: 52.5 + north, longitude: 13.4), placemark: nil, customData: customData, measurements: [:],
            timestamp: nil, sourceID: id)
        return ProcessReading(sensor: sensor, faceplate: faceplate)
    }

    private func presenter(sensors count: Int, prefix: String) -> ProcessPresenter {
        let presenter = ProcessPresenter()
        presenter.replace(readings: (0 ..< count).map { self.reading(id: "\(prefix)\($0)", north: Double($0) * 0.01) })
        return presenter
    }

    @Test func oneAnnotationPerReadingRadiationBeforeLevel() {
        let annotations = EnvironmentMapView.annotations(
            radiation: [self.reading(id: "r1"), self.reading(id: "r2")],
            water: [self.reading(id: "w1"), self.reading(id: "w2"), self.reading(id: "w3")])
        #expect(annotations.map { $0.id } == ["radiation-r1", "radiation-r2", "water-w1", "water-w2", "water-w3"])
        #expect(annotations.map { $0.selector } == [.radiation(.total), .radiation(.total), .water(.level), .water(.level), .water(.level)])
    }

    @Test func everySensorHasItsOwnHomeColorInTheOrderOfTheTab() {
        let annotations = EnvironmentMapView.annotations(
            radiation: [self.reading(id: "r1"), self.reading(id: "r2"), self.reading(id: "r3")],
            water: [self.reading(id: "w1"), self.reading(id: "w2"), self.reading(id: "w3")])
        #expect(annotations.map { $0.displayColor } == [Color.radiation, Color.survey, Color.covid, Color.water, Color.particle, Color.weather])
        #expect(Set(annotations.map { $0.displayColor }).count == 6)
    }

    @Test func withMultipleSensorsOffTheNearestKeepTheirHomeColors() {
        let radiation = self.presenter(sensors: 3, prefix: "r")
        let water = self.presenter(sensors: 3, prefix: "w")
        let annotations = EnvironmentMapView.annotations(
            radiation: radiation.visibleReadings(multiSensor: false), water: water.visibleReadings(multiSensor: false))
        #expect(annotations.map { $0.displayColor } == [Color.radiation, Color.water])
    }

    @Test func theMapAndTheSectionsAgreeOnEachSensorsColor() {
        // The sections take the color from the position in their loop and the map from its own, so this pins that they match.
        let presenter = self.presenter(sensors: 3, prefix: "r")
        let readings = presenter.visibleReadings(multiSensor: true)
        let sections = readings.indices.map { Color.sensor(selector: .radiation(.total), index: $0) }
        #expect(EnvironmentMapView.annotations(radiation: readings, water: []).map { $0.displayColor } == sections)
    }

    @Test func aRadiationStationAndALevelGaugeWithTheSameSourceIdStayApart() {
        // An id used twice on one map silently drops a label.
        let annotations = EnvironmentMapView.annotations(radiation: [self.reading(id: "42")], water: [self.reading(id: "42")])
        #expect(Set(annotations.map { $0.id }).count == 2)
    }

    @Test func aLabelShowsTheSensorsIconAndFaceplate() throws {
        let annotations = EnvironmentMapView.annotations(
            radiation: [self.reading(id: "r1", icon: "atom", faceplate: [.radiation(.total): "Γ: 0.073µSv/h"], north: 0.02)], water: [])
        let label = try #require(annotations.first)
        #expect(label.icon == "atom")
        #expect(label.faceplate == "Γ: 0.073µSv/h")
        #expect(label.location == Location(latitude: 52.52, longitude: 13.4))
        #expect(label.showsLabel == true)
        #expect(label.user == false)
    }

    @Test func aSensorWithoutDataStillGetsADotAndALabel() throws {
        // As on the home map: the nearest sensor is kept even when its station answered with nothing.
        let annotations = EnvironmentMapView.annotations(radiation: [], water: [self.reading(id: "w1", icon: nil)])
        let label = try #require(annotations.first)
        #expect(label.faceplate == "n/a")
        #expect(label.icon == "questionmark.circle")
    }

    @Test func theMapListsTheSameSensorsAsTheSectionsBelowIt() {
        let radiation = self.presenter(sensors: 3, prefix: "r")
        let water = self.presenter(sensors: 3, prefix: "w")
        let off = EnvironmentMapView.annotations(radiation: radiation.visibleReadings(multiSensor: false), water: water.visibleReadings(multiSensor: false))
        #expect(off.map { $0.id } == ["radiation-r0", "water-w0"])
        let on = EnvironmentMapView.annotations(radiation: radiation.visibleReadings(multiSensor: true), water: water.visibleReadings(multiSensor: true))
        #expect(on.count == 6)
        // Each source has its own switch.
        let mixed = EnvironmentMapView.annotations(radiation: radiation.visibleReadings(multiSensor: true), water: water.visibleReadings(multiSensor: false))
        #expect(mixed.map { $0.id } == ["radiation-r0", "radiation-r1", "radiation-r2", "water-w0"])
    }

    @Test func noSensorsMeansNoCamera() {
        #expect(EnvironmentMapView.rect(for: []) == nil)
        #expect(EnvironmentMapView.annotations(radiation: [], water: []).isEmpty == true)
    }

    @Test func aLoneSensorGetsTheMinimumAreaAroundIt() throws {
        let location = Location(latitude: 52.5, longitude: 13.4)
        let rect = try #require(EnvironmentMapView.rect(for: [location]))
        #expect(rect.contains(MKMapPoint(location.coordinate)) == true)
        // About three kilometres each way, and centred on the sensor.
        let metres = rect.size.width / MKMapPointsPerMeterAtLatitude(52.5)
        #expect(metres > 2_900 && metres < 3_100)
        #expect(abs(rect.midX - MKMapPoint(location.coordinate).x) < 1)
        #expect(abs(rect.midY - MKMapPoint(location.coordinate).y) < 1)
    }

    @Test func identicalSensorsDoNotBreakTheCamera() throws {
        let location = Location(latitude: 52.5, longitude: 13.4)
        let rect = try #require(EnvironmentMapView.rect(for: [location, location, location]))
        #expect(rect.size.width.isFinite == true && rect.size.height.isFinite == true)
        #expect(rect.size.width > 0 && rect.size.height > 0)
    }

    @Test func farApartSensorsAreAllInsideWithRoomForTheLabels() throws {
        let north = Location(latitude: 52.6, longitude: 13.4)
        let south = Location(latitude: 52.4, longitude: 13.5)
        let rect = try #require(EnvironmentMapView.rect(for: [north, south]))
        #expect(rect.contains(MKMapPoint(north.coordinate)) == true)
        #expect(rect.contains(MKMapPoint(south.coordinate)) == true)
        // Grown by half its size on each side, so twice the bounding box; the sensors are not on the edge.
        let box = MKMapRect(origin: MKMapPoint(north.coordinate), size: MKMapSize(width: 0, height: 0))
            .union(MKMapRect(origin: MKMapPoint(south.coordinate), size: MKMapSize(width: 0, height: 0)))
        #expect(abs(rect.size.height - box.size.height * 2) < 1)
        #expect(abs(rect.size.width - box.size.width * 2) < 1 || rect.size.width > box.size.width * 2)
        #expect(rect.minY < box.minY && rect.maxY > box.maxY)
    }
}
