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
        presenter.replace(readings: [ProcessReading(sensor: sensor, transformer: transformer)])
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

    @MainActor @Test func readingsForwardTheNearestSensor() throws {
        let origin = Location(latitude: 52, longitude: 13)
        let date = Date.now.addingTimeInterval(-60)
        let sensors = (0 ..< 3).map { index in
            let value = ProcessValue<Dimension>(value: Measurement(value: Double(index + 1), unit: UnitLength.meters), quality: .good, timestamp: date)
            return ProcessSensor(
                name: "Station \(index)", location: Location(latitude: 52 + Double(index) * 0.01, longitude: 13), placemark: index == 0 ? "Berlin" : nil,
                customData: ["icon": "water.waves"], measurements: [.water(.level): [value]], timestamp: date, sourceID: "id-\(index)", distance: Double(index) * 1000)
        }
        let readings = try sensors.map { sensor in
            let transformer = ProcessTransformer()
            try transformer.renderData(sensor: sensor)
            return ProcessReading(sensor: sensor, transformer: transformer)
        }
        let presenter = Presenter()
        #expect(presenter.sensor == nil)
        #expect(presenter.measurements.isEmpty == true)
        #expect(presenter.timestamp == nil)

        presenter.publish(readings: readings)
        #expect(presenter.readings.map { $0.sensor.sourceID } == ["id-0", "id-1", "id-2"])
        #expect(presenter.sensor?.sourceID == "id-0")
        #expect(presenter.timestamp == date)
        #expect(presenter.faceplate[.water(.level)] == "1.00m")
        #expect(presenter.placemark == "Berlin")
        #expect(presenter.location == sensors[0].location)
        #expect(presenter.sensor?.distance == 0)

        presenter.publish(readings: [])
        #expect(presenter.readings.count == 3)
        #expect(presenter.sensor?.sourceID == "id-0")

        presenter.replace(readings: [])
        #expect(presenter.readings.isEmpty == true)
        #expect(presenter.sensor == nil)
        #expect(presenter.timestamp == nil)
    }

    @MainActor @Test func readingsReportTheirOwnAvailabilityAndIdentity() {
        let location = Location(latitude: 52, longitude: 13)
        let date = Date.now.addingTimeInterval(-60)
        func reading(sourceID: String?, values: [(Double, ProcessQuality)]) -> ProcessReading {
            let series = values.enumerated().map { index, entry in
                return ProcessValue<Dimension>(
                    value: Measurement(value: entry.0, unit: UnitLength.meters), quality: entry.1, timestamp: date.addingTimeInterval(Double(index)))
            }
            let sensor = ProcessSensor(
                name: "Station", location: location, placemark: nil, customData: nil, measurements: [.water(.level): series], timestamp: date,
                sourceID: sourceID)
            return ProcessReading(sensor: sensor, measurements: [.water(.level): series])
        }
        let real = reading(sourceID: "gauge-1", values: [(0, .good), (2, .good)])
        #expect(real.isAvailable(selector: .water(.level)) == true)
        #expect(real.isAvailable(selector: .water(.level), treshold: 2) == false)
        #expect(real.isAvailable(selector: .water(.electricalConductivity)) == false)
        // A forecast placeholder is zero with unknown quality; a series of only those has nothing to show.
        #expect(reading(sourceID: nil, values: [(5, .unknown)]).isAvailable(selector: .water(.level)) == false)
        #expect(reading(sourceID: nil, values: []).isAvailable(selector: .water(.level)) == false)

        // The presenter answers for its nearest reading only.
        let presenter = Presenter()
        #expect(presenter.isAvailable(selector: .water(.level)) == false)
        presenter.replace(readings: [reading(sourceID: "far", values: [(0, .good)]), real])
        #expect(presenter.isAvailable(selector: .water(.level)) == false)
        presenter.replace(readings: [real, reading(sourceID: "far", values: [(0, .good)])])
        #expect(presenter.isAvailable(selector: .water(.level)) == true)

        #expect(real.id == "gauge-1")
        let anonymous = reading(sourceID: nil, values: [])
        #expect(anonymous.id == anonymous.sensor.id.uuidString)
    }

    @Test func sensorsSortByDistance() {
        let user = Location(latitude: 52, longitude: 13)
        let sensors = [0.03, 0.01, 0.02].map { offset in
            return ProcessSensor(name: "\(offset)", location: Location(latitude: 52 + offset, longitude: 13), measurements: [:], timestamp: nil)
        }
        #expect(sortByDistance(sensors, from: user, limit: 2).map { $0.name } == ["0.01", "0.02"])
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
