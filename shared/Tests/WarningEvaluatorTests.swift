import DoomKitLocation
import DoomKitProcess
import Foundation
import Testing

@Suite struct WarningEvaluatorTests {
    private static let hkw = Location(latitude: 52.51889, longitude: 13.36528)
    private static let now = Date(timeIntervalSince1970: 1_790_000_000)

    private func defaults() -> UserDefaults {
        let suite = "WarningEvaluatorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? UserDefaults.standard
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    private func reading(
        _ selector: ProcessSelector, current: Measurement<Dimension>? = nil, series: [ProcessValue<Dimension>] = [],
        sourceID: String? = nil, customData: [String: Any]? = nil, name: String = "Station"
    ) -> ProcessReading {
        let sensor = ProcessSensor(
            name: name, location: Self.hkw, placemark: "Tiergarten", customData: customData,
            measurements: [selector: series.isEmpty ? [ProcessValue(value: current ?? Measurement(value: 0, unit: UnitLength.meters))] : series],
            timestamp: Self.now, sourceID: sourceID, distance: 0)
        var currentValues: [ProcessSelector: ProcessValue<Dimension>] = [:]
        if let current { currentValues[selector] = ProcessValue(value: current, quality: .good, timestamp: Self.now) }
        return ProcessReading(sensor: sensor, measurements: sensor.measurements, current: currentValues)
    }

    private func hour(_ offset: Double, _ value: Double, _ unit: Dimension, quality: ProcessQuality = .uncertain) -> ProcessValue<Dimension> {
        return ProcessValue(value: Measurement(value: value, unit: unit), quality: quality, timestamp: Self.now.addingTimeInterval(offset * 3600))
    }

    @Test func levelsFollowTheDirection() {
        let limits = WarningLimits(warning: 50, critical: 100)
        #expect(WarningEvaluator.level(49, limits: limits, direction: .above) == .normal)
        #expect(WarningEvaluator.level(50, limits: limits, direction: .above) == .warning)
        #expect(WarningEvaluator.level(100, limits: limits, direction: .above) == .critical)
        let frost = WarningLimits(warning: 0, critical: -10)
        #expect(WarningEvaluator.level(1, limits: frost, direction: .below) == .normal)
        #expect(WarningEvaluator.level(0, limits: frost, direction: .below) == .warning)
        #expect(WarningEvaluator.level(-12, limits: frost, direction: .below) == .critical)
    }

    @Test func aPollutantIsJudgedPerStationWithItsOwnKey() {
        let reading = self.reading(
            .particle(.pm10), current: Measurement(value: 78, unit: UnitConcentrationMass.microgramsPerCubicMeter), sourceID: "DEBE010")
        let assessments = WarningEvaluator.assessments(readings: [reading], defaults: self.defaults(), now: Self.now)
        let pm10 = assessments.first { $0.key == "particle.pm10.DEBE010" }
        #expect(pm10?.level == .warning)
        #expect(pm10?.family == .particles)
        #expect(pm10?.title == "PM10 warning")
        #expect(pm10?.body == "Tiergarten: 78 µg/m³. The warning limit is 50 µg/m³.")
        // The station reports no ozone, so there is nothing to judge for it.
        #expect(assessments.contains { $0.key.hasPrefix("particle.o3") } == false)
    }

    @Test func readingsAreConvertedIntoTheRuleUnit() {
        // 20 m/s is 72 km/h, over the 65 km/h storm gust limit.
        let reading = self.reading(.weather(.windGust), current: Measurement(value: 20, unit: UnitSpeed.metersPerSecond))
        let gust = WarningEvaluator.assessments(readings: [reading], defaults: self.defaults(), now: Self.now).first { $0.key == "weather.gust" }
        #expect(gust?.level == .warning)
        #expect(gust?.input == "current")
    }

    @Test func currentRainIntensityIsAHeightPerSecond() throws {
        // 30 mm an hour, as WeatherKit reports it.
        let intensity = Measurement<Dimension>(value: 30.0 / 3_600_000, unit: UnitSpeed.metersPerSecond)
        let rule = try #require(WarningRule.catalogue.first { $0.id == "weather.rain" })
        #expect(abs((WarningEvaluator.value(intensity, in: rule) ?? 0) - 30) < 0.0001)
        // A unit of another dimension is not guessed at.
        #expect(WarningEvaluator.value(Measurement(value: 3, unit: UnitTemperature.celsius), in: rule) == nil)
    }

    @Test func theForecastCountsItsWorstHourWithinADay() {
        let celsius = UnitTemperature.celsius
        let series = [
            self.hour(-2, -20, celsius),  // past, does not count
            self.hour(3, 2, celsius),
            self.hour(9, -4, celsius),
            self.hour(12, -1, celsius),
            self.hour(30, -30, celsius),  // beyond the day, does not count
            self.hour(10, -40, celsius, quality: .unknown),  // a placeholder, does not count
        ]
        let reading = self.reading(.forecast(.temperature), series: series)
        let frost = WarningEvaluator.assessments(readings: [reading], defaults: self.defaults(), now: Self.now).first { $0.key == "weather.frost" }
        #expect(frost?.level == .warning)
        #expect(frost?.input == "forecast")
        #expect(frost?.body.hasPrefix("Tiergarten: -4 °C expected ") == true)
    }

    @Test func currentWeatherAndForecastShareAKeyButNotAnInput() {
        let current = self.reading(.weather(.temperature), current: Measurement(value: 5, unit: UnitTemperature.celsius))
        let forecast = self.reading(.forecast(.temperature), series: [self.hour(4, -2, UnitTemperature.celsius)])
        let assessments = WarningEvaluator.assessments(readings: [current, forecast], defaults: self.defaults(), now: Self.now)
            .filter { $0.key == "weather.frost" }
        #expect(assessments.map { $0.input } == ["current", "forecast"])
        #expect(assessments.map { $0.level } == [.normal, .warning])
    }

    @Test func pollsAreNotJudged() {
        let reading = self.reading(.survey(.cdu), current: Measurement(value: 30, unit: UnitPercentage.percent))
        #expect(WarningEvaluator.assessments(readings: [reading], defaults: self.defaults(), now: Self.now).isEmpty)
    }

    @Test func levelMarksPreferTheFloodStages() {
        let celle = WarningEvaluator.levelMarks(["MW": 1.92, "MHW": 4.12, "M_I": 3.0, "M_II": 3.4, "HSW": 3.1, "HHW": 5.28])
        #expect(celle?.warning == LevelMarks.Mark(name: "M_I", value: 3.0))
        #expect(celle?.critical == LevelMarks.Mark(name: "M_II", value: 3.4))
    }

    @Test func withoutStagesTheCriticalMarkIsTheFirstOneAboveTheWarning() {
        // The highest navigable level lies below the mean high water here, so the record high is the critical mark.
        let marks = WarningEvaluator.levelMarks(["MHW": 4.12, "HSW": 3.1, "HHW": 5.28])
        #expect(marks?.warning == LevelMarks.Mark(name: "MHW", value: 4.12))
        #expect(marks?.critical == LevelMarks.Mark(name: "HHW", value: 5.28))
        #expect(WarningEvaluator.levelMarks(["MHW": 4.0])?.critical == nil)
        #expect(WarningEvaluator.levelMarks(["MW": 2.0, "HHW": 5.0]) == nil)
    }

    @Test func aGaugeIsJudgedAgainstItsOwnMarks() {
        let marks: [String: Any] = ["icon": "water.waves", "marks": ["M_I": 3.0, "M_II": 3.4]]
        let high = self.reading(
            .water(.level), current: Measurement(value: 345, unit: UnitLength.centimeters), sourceID: "celle", customData: marks,
            name: "CELLE")
        let assessment = WarningEvaluator.assessments(readings: [high], defaults: self.defaults(), now: Self.now).first
        #expect(assessment?.key == "level.marks.celle")
        #expect(assessment?.level == .critical)
        #expect(assessment?.body == "CELLE: 3.45 m, at or above flood stage II at 3.40 m.")
        // A gauge without marks raises nothing.
        let plain = self.reading(.water(.level), current: Measurement(value: 9, unit: UnitLength.meters), sourceID: "canal")
        #expect(WarningEvaluator.assessments(readings: [plain], defaults: self.defaults(), now: Self.now).isEmpty)
    }

    @Test func hazardsAreJudgedBySeverityOnePerWarning() {
        func hazard(_ id: String, _ severity: Hazard.Severity) -> Hazard {
            return Hazard(
                id: id, feed: .dwd, event: nil, headline: "Sturmböen", description: "", instruction: nil, severity: severity, sent: Self.now,
                expires: nil, areaDescription: "Berlin", location: Self.hkw, distance: 0, placemark: nil)
        }
        let assessments = WarningEvaluator.assessments(
            hazards: [hazard("a", .minor), hazard("b", .moderate), hazard("c", .extreme)], defaults: self.defaults())
        #expect(assessments.map { $0.key } == ["hazard.a", "hazard.b", "hazard.c"])
        #expect(assessments.map { $0.level } == [.normal, .warning, .critical])
        #expect(assessments[1].title == "Sturmböen")
        #expect(assessments[1].body == "Moderate · Berlin")
    }

    @Test func fuelIsJudgedByTheCheapestOpenStation() {
        func station(_ id: String, _ e5: Double, open: Bool = true, distance: Double = 1000) -> FuelStation {
            return FuelStation(
                id: id, name: id, brand: nil, street: nil, houseNumber: nil, location: Self.hkw, distance: distance, isOpen: open,
                prices: [.e5: e5])
        }
        let stations = [station("shut", 1.50, open: false), station("far", 2.059, distance: 5000), station("near", 2.059), station("dear", 2.30)]
        let assessments = WarningEvaluator.assessments(stations: stations, fuel: .e5, radius: 10, defaults: self.defaults())
        #expect(assessments.count == 1)
        #expect(assessments.first?.key == "fuel.price")
        #expect(assessments.first?.level == .warning)
        #expect(assessments.first?.body.hasPrefix("Cheapest Super E5 within 10 km: 2.059 €/l at near.") == true)
        #expect(WarningEvaluator.assessments(stations: [], fuel: .e5, radius: 10, defaults: self.defaults()).isEmpty)
    }
}
