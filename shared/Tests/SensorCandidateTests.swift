import DoomKitLocation
import DoomKitProcess
import Foundation
import Testing

@Suite struct SensorCandidateTests {
    private actor Geocoder {
        private(set) var calls: [Location] = []
        private let answers: [Location: String]

        init(answers: [Location: String]) {
            self.answers = answers
        }

        func address(for location: Location) -> String? {
            self.calls.append(location)
            return self.answers[location]
        }
    }

    private static let user = Location(latitude: 52.5, longitude: 13.4)

    private static func location(_ north: Double) -> Location {
        return Location(latitude: 52.5 + north, longitude: 13.4)
    }

    private static func candidate(_ id: String, north: Double, data: Bool = true) -> SensorCandidate {
        var measurements: [ProcessSelector: [ProcessValue<Dimension>]] = [:]
        if data == true {
            measurements[.water(.level)] = [ProcessValue<Dimension>(value: Measurement(value: 1, unit: UnitLength.meters), quality: .good, timestamp: .now)]
        }
        return SensorCandidate(id: id, name: "Name \(id)", location: Self.location(north), customData: ["icon": "x"], measurements: measurements)
    }

    private func sensors(
        _ candidates: [SensorCandidate], geocoding answers: [Location: String]
    ) async throws -> (sensors: [ProcessSensor], geocoded: [Location]) {
        let geocoder = Geocoder(answers: answers)
        let sensors = try await SensorCandidate.sensors(from: candidates, near: Self.user) { await geocoder.address(for: $0) }
        return (sensors: sensors, geocoded: await geocoder.calls)
    }

    @Test func onlyTheFirstSensorIsGeocoded() async throws {
        let candidates = [Self.candidate("a", north: 0.01), Self.candidate("b", north: 0.02), Self.candidate("c", north: 0.03)]
        let result = try await self.sensors(candidates, geocoding: [Self.location(0.01): "Address A", Self.location(0.02): "Address B"])
        #expect(result.sensors.map { $0.sourceID } == ["a", "b", "c"])
        #expect(result.sensors.map { $0.placemark } == ["Address A", nil, nil])
        #expect(result.geocoded == [Self.location(0.01)])
    }

    @Test func aFirstCandidateThatCannotBeGeocodedIsSkipped() async throws {
        let candidates = [Self.candidate("a", north: 0.01), Self.candidate("b", north: 0.02), Self.candidate("c", north: 0.03)]
        let result = try await self.sensors(candidates, geocoding: [Self.location(0.02): "Address B"])
        // The skipped candidate is gone, so the nearest sensor is the first one with an address.
        #expect(result.sensors.map { $0.sourceID } == ["b", "c"])
        #expect(result.sensors.first?.placemark == "Address B")
        #expect(result.geocoded == [Self.location(0.01), Self.location(0.02)])
    }

    @Test func noCandidateThatCanBeGeocodedGivesNoSensors() async throws {
        let candidates = [Self.candidate("a", north: 0.01), Self.candidate("b", north: 0.02)]
        let result = try await self.sensors(candidates, geocoding: [:])
        #expect(result.sensors.isEmpty == true)
        #expect(result.geocoded.count == 2)
    }

    @Test func theFirstSensorIsKeptWithoutDataButLaterOnesAreNot() async throws {
        let candidates = [
            Self.candidate("a", north: 0.01, data: false), Self.candidate("b", north: 0.02, data: false), Self.candidate("c", north: 0.03)
        ]
        let result = try await self.sensors(candidates, geocoding: [Self.location(0.01): "Address A"])
        #expect(result.sensors.map { $0.sourceID } == ["a", "c"])
        #expect(result.sensors.first?.measurements.isEmpty == true)
    }

    @Test func sensorsCarryTheirSourceDistanceAndOnlyNonEmptySeries() async throws {
        let value = ProcessValue<Dimension>(value: Measurement(value: 1, unit: UnitLength.meters), quality: .good, timestamp: .now)
        let mixed = SensorCandidate(
            id: "m", name: "Mixed", location: Self.location(0.02), customData: [:],
            measurements: [.particle(.pm10): [value], .particle(.pm25): []])
        let result = try await self.sensors([Self.candidate("a", north: 0.01), mixed], geocoding: [Self.location(0.01): "Address A"])
        let distances = result.sensors.compactMap { $0.distance }
        #expect(distances.count == 2)
        #expect(distances[0] > 1_000 && distances[0] < 1_200)
        #expect(distances[1] > distances[0])
        #expect(result.sensors[1].measurements.keys.contains(.particle(.pm10)) == true)
        #expect(result.sensors[1].measurements.keys.contains(.particle(.pm25)) == false)
    }
}
