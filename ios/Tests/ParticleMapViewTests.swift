import DoomKitLocation
import DoomKitProcess
import Foundation
import SwiftUI
import Testing

@MainActor
@Suite struct ParticleMapViewTests {
    private func reading(id: String?, faceplate: [ProcessSelector: String] = [:], north: Double = 0, icon: String? = "aqi.medium") -> ProcessReading {
        var customData: [String: Any]? = nil
        if let icon = icon {
            customData = ["icon": icon]
        }
        let sensor = ProcessSensor(
            name: "Station", location: Location(latitude: 52.5 + north, longitude: 13.4), placemark: nil, customData: customData, measurements: [:],
            timestamp: nil, sourceID: id)
        return ProcessReading(sensor: sensor, faceplate: faceplate)
    }

    private func presenter(stations count: Int) -> ProcessPresenter {
        let presenter = ProcessPresenter()
        presenter.replace(readings: (0 ..< count).map { self.reading(id: "p\($0)", north: Double($0) * 0.01) })
        return presenter
    }

    @Test func oneAnnotationPerStationWithItsOwnColorNearestFirst() {
        let annotations = ParticleMapView.annotations(particles: [self.reading(id: "p0"), self.reading(id: "p1"), self.reading(id: "p2")])
        #expect(annotations.map { $0.id } == ["particles-p0", "particles-p1", "particles-p2"])
        #expect(annotations.map { $0.displayColor } == [Color.particle, Color.survey, Color.weather])
        #expect(annotations.map { $0.icon } == ["aqi.medium", "aqi.medium", "aqi.medium"])
    }

    @Test func aLabelShowsTheFirstPollutantOfTheTabsOrder() {
        // The tab lists PM10, PM2.5, ozone, then nitrogen dioxide, so that is the order the label follows.
        let all: [ProcessSelector: String] = [.particle(.no2): "NO2: 30", .particle(.o3): "O3: 60", .particle(.pm25): "PM25: 8", .particle(.pm10): "PM10: 12"]
        #expect(ParticleMapView.selector(for: self.reading(id: "a", faceplate: all)) == .particle(.pm10))
        let withoutPM10 = all.filter { $0.key != .particle(.pm10) }
        #expect(ParticleMapView.selector(for: self.reading(id: "a", faceplate: withoutPM10)) == .particle(.pm25))
        let onlyGases: [ProcessSelector: String] = [.particle(.no2): "NO2: 30", .particle(.o3): "O3: 60"]
        #expect(ParticleMapView.selector(for: self.reading(id: "a", faceplate: onlyGases)) == .particle(.o3))
    }

    @Test func theLabelTextIsThatPollutantsFaceplate() throws {
        let annotations = ParticleMapView.annotations(
            particles: [self.reading(id: "a", faceplate: [.particle(.pm25): "PM25: 8µg/m³", .particle(.no2): "NO2: 30µg/m³"])])
        let label = try #require(annotations.first)
        #expect(label.selector == .particle(.pm25))
        #expect(label.faceplate == "PM25: 8µg/m³")
    }

    @Test func aStationWithoutValuesStillGetsADotAndALabel() throws {
        // As on the home map: the nearest is kept even when its station answered with nothing.
        let annotations = ParticleMapView.annotations(particles: [self.reading(id: "a", icon: nil)])
        let label = try #require(annotations.first)
        #expect(label.selector == .particle(.pm10))
        #expect(label.faceplate == "n/a")
        #expect(label.icon == "questionmark.circle")
    }

    @Test func theAllMarkerIsNeverChosen() {
        #expect(ParticleMapView.selector(for: self.reading(id: "a", faceplate: [.particle(.all): "x"])) == .particle(.pm10))
    }

    @Test func theMapListsTheSameStationsAsTheSectionsBelowIt() {
        let presenter = self.presenter(stations: 3)
        #expect(ParticleMapView.annotations(particles: presenter.visibleReadings(multiSensor: false)).map { $0.id } == ["particles-p0"])
        #expect(ParticleMapView.annotations(particles: presenter.visibleReadings(multiSensor: true)).count == 3)
    }

    @Test func theMapAndTheSectionsAgreeOnEachStationsColor() {
        // The sections take the color from the position in their loop, the map from its own, so this pins that they match.
        let readings = self.presenter(stations: 3).visibleReadings(multiSensor: true)
        let sections = readings.indices.map { Color.sensor(selector: .particle(.pm10), index: $0) }
        #expect(ParticleMapView.annotations(particles: readings).map { $0.displayColor } == sections)
    }

    @Test func noStationsMeansNoAnnotations() {
        #expect(ParticleMapView.annotations(particles: []).isEmpty == true)
    }
}
