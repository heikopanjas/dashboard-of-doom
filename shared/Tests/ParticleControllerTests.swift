import DoomKitLocation
import DoomKitProcess
import Foundation
import Testing

@Suite struct ParticleControllerTests {
    private actor Probes {
        private(set) var codes: [String] = []

        func record(_ code: String) {
            self.codes.append(code)
        }
    }

    private static let relevant: [ProcessSelector] = [.particle(.pm10), .particle(.pm25), .particle(.no2), .particle(.o3)]

    private static func station(_ code: String) -> ParticleController.Station {
        return ParticleController.Station(id: code, code: code, name: "Station \(code)", location: Location(latitude: 52.5, longitude: 13.4))
    }

    /// Five stations, already ordered by distance.
    private static let stations = ["a", "b", "c", "d", "e"].map { Self.station($0) }

    private static func measurements(_ selectors: [ProcessSelector]) -> [ProcessSelector: [ProcessValue<Dimension>]] {
        var result: [ProcessSelector: [ProcessValue<Dimension>]] = [:]
        for selector in selectors {
            let value = ProcessValue<Dimension>(value: Measurement(value: 1, unit: UnitConcentrationMass.microgramsPerCubicMeter), quality: .good, timestamp: .now)
            result[selector] = [value]
        }
        return result
    }

    private static func codes(_ results: [ParticleController.StationResult]) -> [String] {
        return results.map { $0.station.code }
    }

    private func select(
        nearest: Bool = false, limit: Int = 3, from stations: [ParticleController.Station] = ParticleControllerTests.stations,
        reporting: [String: [ProcessSelector]]
    ) async -> (results: [ParticleController.StationResult], probed: [String]) {
        let probes = Probes()
        let results = await ParticleController.selectStations(from: stations, nearest: nearest, limit: limit) { station in
            await probes.record(station.code)
            return reporting[station.code].map { Self.measurements($0) }
        }
        return (results: results, probed: await probes.codes)
    }

    @Test func theNearestQualifyingStationIsFirstAndTheNextTwoFollow() async {
        let selection = await self.select(reporting: ["a": Self.relevant])
        #expect(Self.codes(selection.results) == ["a", "b", "c"])
        // Probing stops at the first station that qualifies, and only that one carries measurements.
        #expect(selection.probed == ["a"])
        #expect(selection.results.map { $0.cachedMeasurements != nil } == [true, false, false])
    }

    @Test func stationsThatDoNotQualifyAreSkippedForTheFirstSensorOnly() async {
        // The nearest two are skipped, and so are not reported at all: the array stays ordered by distance from its first sensor on.
        let selection = await self.select(reporting: ["a": [.particle(.pm10)], "b": [], "c": Self.relevant, "d": [.particle(.pm10)]])
        #expect(Self.codes(selection.results) == ["c", "d", "e"])
        #expect(selection.probed == ["a", "b", "c"])
        #expect(selection.results.map { $0.cachedMeasurements != nil } == [true, false, false])
    }

    @Test func aStationWithoutAnswerIsSkippedLikeOneThatDoesNotQualify() async {
        let selection = await self.select(reporting: ["b": Self.relevant])
        #expect(Self.codes(selection.results) == ["b", "c", "d"])
        #expect(selection.probed == ["a", "b"])
    }

    @Test func whenNoStationQualifiesTheNearestAreUsed() async {
        let partial = Dictionary(uniqueKeysWithValues: Self.stations.map { ($0.code, [ProcessSelector.particle(.pm10)]) })
        let selection = await self.select(reporting: partial)
        #expect(Self.codes(selection.results) == ["a", "b", "c"])
        #expect(selection.probed == ["a", "b", "c", "d", "e"])
        #expect(selection.results.allSatisfy { $0.cachedMeasurements == nil } == true)
    }

    @Test func theNearestPreferenceUsesTheNearestStationsWithoutProbing() async {
        let selection = await self.select(nearest: true, reporting: [:])
        #expect(Self.codes(selection.results) == ["a", "b", "c"])
        #expect(selection.probed.isEmpty == true)
        #expect(selection.results.allSatisfy { $0.cachedMeasurements == nil } == true)
    }

    @Test func fewerStationsThanTheLimitAreAllReported() async {
        let two = Array(Self.stations.prefix(2))
        #expect(Self.codes(await self.select(from: two, reporting: ["a": Self.relevant]).results) == ["a", "b"])
        #expect(await self.select(from: [], reporting: [:]).results.isEmpty == true)
    }

    @Test(arguments: [0, 1])
    func aLimitOfOneReportsOnlyTheFirstSensor(limit: Int) async {
        // The macOS cap: one sensor, chosen the same way, and a limit below one is treated as one.
        #expect(Self.codes(await self.select(limit: limit, reporting: ["b": Self.relevant]).results) == ["b"])
        #expect(Self.codes(await self.select(nearest: true, limit: limit, reporting: [:]).results) == ["a"])
    }

    @Test func aStationNeedsAllFourPollutants() {
        #expect(ParticleController.stationHasRelevantMeasurements(Self.measurements(Self.relevant)) == true)
        #expect(ParticleController.stationHasRelevantMeasurements(Self.measurements(Self.relevant + [.particle(.so2), .particle(.co)])) == true)
        for missing in Self.relevant {
            let others = Self.relevant.filter { $0 != missing }
            #expect(ParticleController.stationHasRelevantMeasurements(Self.measurements(others)) == false)
        }
        #expect(ParticleController.stationHasRelevantMeasurements([:]) == false)
    }
}
