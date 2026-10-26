import DoomKitLocation
import DoomKitProcess
import Foundation
import MapKit
import SwiftUI
import Testing

@MainActor
@Suite struct SensorScreenMapTests {
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

    @Test(arguments: [false, true])
    func eachScreenMapsExactlyTheReadingsItsSectionsShow(multiSensor: Bool) {
        let presenter = self.presenter(sensors: 6, prefix: "station")
        let readings = presenter.visibleReadings(multiSensor: multiSensor)
        for (annotations, selector) in [
            (SensorAnnotations.water(readings), ProcessSelector.water(.level)),
            (SensorAnnotations.radiation(readings), ProcessSelector.radiation(.total))
        ] {
            #expect(annotations.count == (multiSensor == true ? 6 : 1))
            #expect(Set(annotations.map { $0.id }).count == annotations.count)
            #expect(Set(annotations.map { $0.displayColor }).count == annotations.count)
            #expect(annotations.map { $0.displayColor } == readings.indices.map { Color.sensor(selector: selector, index: $0) })
            #expect(annotations.map { $0.location } == readings.map { $0.sensor.location })
        }
    }

    @Test func annotationIdentitiesSurviveRefreshes() {
        let first = (0 ..< 6).map { self.reading(id: "gauge\($0)") }
        let refreshed = (0 ..< 6).map { self.reading(id: "gauge\($0)") }
        #expect(SensorAnnotations.water(first).map { $0.id } == SensorAnnotations.water(refreshed).map { $0.id })
        #expect(SensorAnnotations.radiation(first).map { $0.id } == SensorAnnotations.radiation(refreshed).map { $0.id })
    }

    @Test func aLabelShowsTheSensorsIconAndFaceplate() throws {
        let annotations = SensorAnnotations.radiation([
            self.reading(id: "r1", icon: "atom", faceplate: [.radiation(.total): "Γ: 0.073µSv/h"], north: 0.02)
        ])
        let label = try #require(annotations.first)
        #expect(label.icon == "atom")
        #expect(label.faceplate == "Γ: 0.073µSv/h")
        #expect(label.location == Location(latitude: 52.52, longitude: 13.4))
        #expect(label.showsLabel == true)
        #expect(label.user == false)
    }

    @Test func aSensorWithoutDataStillGetsADotAndALabel() throws {
        let label = try #require(SensorAnnotations.water([self.reading(id: "w1", icon: nil)]).first)
        #expect(label.faceplate == "n/a")
        #expect(label.icon == "questionmark.circle")
    }

    @Test func noSensorsMeansNoCamera() {
        #expect(SensorMapView.rect(for: []) == nil)
        #expect(SensorAnnotations.water([]).isEmpty == true)
        #expect(SensorAnnotations.radiation([]).isEmpty == true)
    }

    @Test func aLoneSensorGetsTheMinimumAreaAroundIt() throws {
        let location = Location(latitude: 52.5, longitude: 13.4)
        let rect = try #require(SensorMapView.rect(for: [location]))
        #expect(rect.contains(MKMapPoint(location.coordinate)) == true)
        // About three kilometres each way, and centred on the sensor.
        let metres = rect.size.width / MKMapPointsPerMeterAtLatitude(52.5)
        #expect(metres > 2_900 && metres < 3_100)
        #expect(abs(rect.midX - MKMapPoint(location.coordinate).x) < 1)
        #expect(abs(rect.midY - MKMapPoint(location.coordinate).y) < 1)
    }

    @Test func identicalSensorsDoNotBreakTheCamera() throws {
        let location = Location(latitude: 52.5, longitude: 13.4)
        let rect = try #require(SensorMapView.rect(for: [location, location, location]))
        #expect(rect.size.width.isFinite == true && rect.size.height.isFinite == true)
        #expect(rect.size.width > 0 && rect.size.height > 0)
    }

    @Test func farApartSensorsAreAllInsideWithRoomForTheLabels() throws {
        let north = Location(latitude: 52.6, longitude: 13.4)
        let south = Location(latitude: 52.4, longitude: 13.5)
        let rect = try #require(SensorMapView.rect(for: [north, south]))
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
