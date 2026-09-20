import DoomKitProcess
import DoomKitLocation
import Foundation
import Testing

struct PublicAPITests {
    private struct Place: ProcessLocatable { let location: Location }
    private struct Controller: ProcessController {
        func refreshData(for location: Location) async throws -> [ProcessSensor] { return [] }
    }
    @MainActor private final class Presenter: ProcessPresenter, ProcessRefreshable {
        func refreshData(location: Location) async {}
    }
    private final class Transformer: ProcessTransformer {
        override func renderCurrent(measurements: [ProcessSelector: [ProcessValue<Dimension>]]) -> [ProcessSelector: ProcessValue<Dimension>] { return [:] }
        override func renderFaceplate(current: [ProcessSelector: ProcessValue<Dimension>]) -> [ProcessSelector: String] { return [.water(.level): "override"] }
        override func renderRange(measurements: [ProcessSelector: [ProcessValue<Dimension>]]) -> [ProcessSelector: ClosedRange<Double>] { return [:] }
        override func renderTrend(measurements: [ProcessSelector: [ProcessValue<Dimension>]]) -> [ProcessSelector: String] { return [:] }
        override func renderData(sensor: ProcessSensor) throws { try super.renderData(sensor: sensor) }
    }

    @MainActor @Test func modelsAndOverrides() throws {
        let location = Location(latitude: 52, longitude: 13)
        let date = Date.now.addingTimeInterval(-60)
        let value = ProcessValue<Dimension>(value: Measurement(value: 2, unit: UnitLength.meters), customData: ["nested": ["answer": 42]], quality: .good, timestamp: date)
        let previous = ProcessValue<Dimension>(value: Measurement(value: 1, unit: UnitLength.meters), quality: .good, timestamp: date.addingTimeInterval(-60))
        let sensor = ProcessSensor(name: "Station", location: location, placemark: "Berlin", customData: ["label": "Level", "icon": "water.waves"], measurements: [.water(.level): [previous, value]], timestamp: date)
        #expect((value.customData?["nested"] as? [String: Int])?["answer"] == 42)
        #expect(value.id != previous.id)
        let transformer = ProcessTransformer()
        try transformer.renderData(sensor: sensor)
        #expect(transformer.current[.water(.level)]?.id == value.id)
        #expect(transformer.faceplate[.water(.level)] == "2.00m")
        #expect(transformer.range[.water(.level)] == 1...2)
        #expect(transformer.trend[.water(.level)] == "arrow.up.forward.circle")
        let presenter = Presenter()
        presenter.sensor = sensor
        presenter.measurements = transformer.measurements
        #expect(presenter.label == "Level")
        #expect(presenter.icon == "water.waves")
        #expect(presenter.placemark == "Berlin")
        #expect(presenter.location == location)
        #expect(presenter.isAvailable(selector: .water(.level)) == true)
        let overridden = Transformer()
        try overridden.renderData(sensor: sensor)
        #expect(overridden.current.isEmpty == true)
        #expect(overridden.faceplate[.water(.level)] == "override")
        #expect(ProcessValue<UnitLength>().quality == .unknown)
        #expect(ProcessSensor(name: "Empty", location: location, measurements: [:], timestamp: nil).customData == nil)
        #expect(ProcessSensor(name: "Empty", location: location, placemark: "Address", measurements: [:], timestamp: nil).placemark == "Address")
        _ = Controller()
    }

    @Test func selectors() {
        for value in ProcessSelector.Covid.allCases { #expect(ProcessSelector.covid(from: value.rawValue) == .covid(value)) }
        for value in ProcessSelector.Water.allCases { #expect(ProcessSelector.water(from: value.rawValue) == .water(value)) }
        for value in ProcessSelector.Particle.allCases { #expect(ProcessSelector.particle(from: value.rawValue) == .particle(value)) }
        for value in ProcessSelector.Survey.allCases { #expect(ProcessSelector.survey(from: value.rawValue) == .survey(value)) }
        #expect(ProcessSelector.particle(.pm25).rawValue == 9)
        #expect(ProcessSelector.survey(.bsw).rawValue == 23)
        #expect(ProcessSelector.weather(.windGust).rawValue == 12)
        #expect(ProcessSelector.forecast(.windGust).rawValue == 11)
        #expect(ProcessSelector.radiation(.terrestrial).rawValue == 2)
        #expect(ProcessSelector.covid(from: -10) == nil)
        #expect(ProcessSelector.water(from: -10) == nil)
        #expect(ProcessSelector.particle(from: -10) == nil)
        #expect(ProcessSelector.survey(from: -10) == nil)
    }

    @Test func geography() {
        let origin = Location(latitude: 0, longitude: 0)
        let near = Place(location: origin)
        let far = Place(location: Location(latitude: 0, longitude: 1))
        #expect(sortByDistance([far, near], from: origin, limit: 1).first?.location == origin)
        #expect(minDistance([far, near], from: origin).value == 0)
        #expect(maxDistance([far, near], from: origin).value > 100_000)
        #expect(maxDistance([Place](), from: origin).value == 0)
        let polygon = [Location(latitude: -0.5, longitude: -0.5), Location(latitude: 0.5, longitude: -0.5), Location(latitude: 0.5, longitude: 0.5), Location(latitude: -0.5, longitude: 0.5)]
        #expect(isItemInPolygon(near, polygon: polygon) == true)
        #expect(filterItemsInPolygon([near, far], polygon: polygon).count == 1)
        #expect(isPointInPolygon(point: origin, polygon: []) == false)
    }
}
