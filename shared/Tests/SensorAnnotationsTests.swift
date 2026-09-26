import DoomKitLocation
import DoomKitProcess
import Foundation
import SwiftUI
import Testing

@Suite struct SensorAnnotationsTests {
    private func reading(id: String?, icon: String? = "atom", faceplate: [ProcessSelector: String] = [:]) -> ProcessReading {
        let sensor = ProcessSensor(
            name: "Name", location: Location(latitude: 52.5, longitude: 13.4), placemark: nil,
            customData: icon.map { ["icon": $0] }, measurements: [:], timestamp: nil, sourceID: id)
        return ProcessReading(sensor: sensor, faceplate: faceplate)
    }

    @Test func idsCarryTheCategoryAndTheSourceId() {
        #expect(SensorAnnotations.water([self.reading(id: "w1"), self.reading(id: "w2")]).map { $0.id } == ["water-w1", "water-w2"])
        #expect(SensorAnnotations.radiation([self.reading(id: "r1")]).map { $0.id } == ["radiation-r1"])
        #expect(SensorAnnotations.particles([self.reading(id: "p1")]).map { $0.id } == ["particles-p1"])
    }

    @Test func theColorFollowsThePositionAndMatchesTheHeaders() {
        let readings = (0 ..< 6).map { self.reading(id: "w\($0)") }
        let colors = SensorAnnotations.water(readings).map { $0.displayColor }
        #expect(colors == (0 ..< 6).map { Color.sensor(selector: .water(.level), index: $0) })
        #expect(colors.first == Color.faceplate(selector: .water(.level)))
        #if os(macOS)
        // Level has a tab and a map of its own on macOS, so six gauges have six colors.
        #expect(Set(colors).count == 6)
        #endif
    }

    @Test func missingIconAndValueFallBack() {
        let annotation = SensorAnnotations.radiation([self.reading(id: "r", icon: nil)]).first
        #expect(annotation?.icon == "questionmark.circle")
        #expect(annotation?.faceplate == "n/a")
        let labelled = SensorAnnotations.radiation([self.reading(id: "r", faceplate: [.radiation(.total): "0.08µSv"])]).first
        #expect(labelled?.faceplate == "0.08µSv")
    }

    @Test func aStationShowsTheFirstPollutantThatHasAValue() {
        let ozone = self.reading(id: "p", faceplate: [.particle(.o3): "60µg", .particle(.no2): "20µg"])
        #expect(SensorAnnotations.particleSelector(for: ozone) == .particle(.o3))
        #expect(SensorAnnotations.particles([ozone]).first?.faceplate == "60µg")
        // Nothing at all still gets a PM10 label.
        #expect(SensorAnnotations.particleSelector(for: self.reading(id: "e")) == .particle(.pm10))
    }
}
