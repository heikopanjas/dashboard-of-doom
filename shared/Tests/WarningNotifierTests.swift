import DoomKitLocation
import DoomKitProcess
import Foundation
import Testing

@MainActor
@Suite struct WarningNotifierTests {
    @MainActor private final class Fixture {
        let suite = "WarningNotifierTests.\(UUID())"
        let defaults: UserDefaults
        var now = Date(timeIntervalSince1970: 1_790_000_000)
        var measured = true
        var posted: [WarningNotice] = []
        var notifier: WarningNotifier!

        init(enabled: Bool = true) {
            self.defaults = UserDefaults(suiteName: self.suite) ?? .standard
            self.defaults.removePersistentDomain(forName: self.suite)
            self.defaults.set(enabled, forKey: WarningPreferences.enabledKey)
            self.notifier = WarningNotifier(
                defaults: self.defaults, now: { [unowned self] in self.now }, isLocationMeasured: { [unowned self] in self.measured },
                post: { [unowned self] in self.posted.append($0) })
        }

        deinit {
            UserDefaults().removePersistentDomain(forName: self.suite)
        }

        func advance(hours: Double) {
            self.now = self.now.addingTimeInterval(hours * 3600)
        }
    }

    private func assessment(
        _ level: WarningLevel, key: String = "radiation.total.kenn", input: String = "current", family: WarningFamily = .radiation
    ) -> WarningAssessment {
        return WarningAssessment(key: key, input: input, family: family, level: level, title: "Dose Rate \(level.label)", body: "body")
    }

    private func radiation(_ microsieverts: Double) -> ProcessReading {
        let value = ProcessValue<Dimension>(value: Measurement(value: microsieverts, unit: UnitRadiation.microsieverts), quality: .good)
        let sensor = ProcessSensor(
            name: "Berlin", location: Location(latitude: 52.5, longitude: 13.4), placemark: "Tiergarten", customData: nil,
            measurements: [.radiation(.total): [value]], timestamp: .now, sourceID: "kenn", distance: 0)
        return ProcessReading(sensor: sensor, measurements: sensor.measurements, current: [.radiation(.total): value])
    }

    @Test func nothingIsSentWhileTheMasterSwitchIsOff() {
        let fixture = Fixture(enabled: false)
        fixture.notifier.check(readings: [self.radiation(5)])
        #expect(fixture.posted.isEmpty)
        #expect(fixture.notifier.load().isEmpty)
    }

    @Test func nothingIsSentForTheFallbackLocation() {
        let fixture = Fixture()
        fixture.measured = false
        fixture.notifier.check(readings: [self.radiation(5)])
        #expect(fixture.posted.isEmpty)
    }

    @Test func nothingIsSentForASwitchedOffFamily() {
        let fixture = Fixture()
        fixture.defaults.set(false, forKey: WarningPreferences.familyKey(.radiation))
        fixture.notifier.check(readings: [self.radiation(5)])
        #expect(fixture.posted.isEmpty)
    }

    @Test func readingsEndToEnd() {
        let fixture = Fixture()
        fixture.notifier.check(readings: [self.radiation(0.1)])
        #expect(fixture.posted.isEmpty)
        fixture.notifier.check(readings: [self.radiation(0.7)])
        #expect(fixture.posted.map { $0.identifier } == ["radiation.total.kenn"])
        #expect(fixture.posted.first?.level == .warning)
        #expect(fixture.posted.first?.family == .radiation)
    }

    @Test func onlyEscalationNotifies() {
        let fixture = Fixture()
        fixture.notifier.process([self.assessment(.warning)])
        fixture.notifier.process([self.assessment(.warning)])
        #expect(fixture.posted.map { $0.level } == [.warning])
        fixture.notifier.process([self.assessment(.critical)])
        #expect(fixture.posted.map { $0.level } == [.warning, .critical])
        fixture.notifier.process([self.assessment(.critical)])
        fixture.notifier.process([self.assessment(.warning)])
        #expect(fixture.posted.count == 2)
    }

    @Test func straightToCriticalIsOneNotice() {
        let fixture = Fixture()
        fixture.notifier.process([self.assessment(.critical)])
        #expect(fixture.posted.map { $0.level } == [.critical])
    }

    @Test func backToNormalReArmsButTheSameLevelWaitsSixHours() {
        let fixture = Fixture()
        fixture.notifier.process([self.assessment(.warning)])
        fixture.advance(hours: 1)
        fixture.notifier.process([self.assessment(.normal)])
        fixture.notifier.process([self.assessment(.warning)])
        // Hovering at the limit: held back.
        #expect(fixture.posted.count == 1)
        fixture.advance(hours: 5.5)
        fixture.notifier.process([self.assessment(.normal)])
        fixture.notifier.process([self.assessment(.warning)])
        #expect(fixture.posted.count == 2)
    }

    @Test func easingToWarningLetsCriticalNotifyAgainAfterSixHours() {
        let fixture = Fixture()
        fixture.notifier.process([self.assessment(.critical)])
        fixture.notifier.process([self.assessment(.warning)])
        fixture.notifier.process([self.assessment(.critical)])
        #expect(fixture.posted.count == 1)
        fixture.advance(hours: 7)
        fixture.notifier.process([self.assessment(.warning)])
        fixture.notifier.process([self.assessment(.critical)])
        #expect(fixture.posted.map { $0.level } == [.critical, .critical])
    }

    @Test func eachSensorHasItsOwnKey() {
        let fixture = Fixture()
        fixture.notifier.process([self.assessment(.warning, key: "radiation.total.a"), self.assessment(.warning, key: "radiation.total.b")])
        #expect(fixture.posted.map { $0.identifier } == ["radiation.total.a", "radiation.total.b"])
    }

    @Test func aForecastFrostDoesNotNotifyAgainWhenItArrives() {
        let fixture = Fixture()
        let frost = { (level: WarningLevel, input: String) in
            self.assessment(level, key: "weather.frost", input: input, family: .weather)
        }
        fixture.notifier.process([frost(.normal, "current"), frost(.warning, "forecast")])
        #expect(fixture.posted.count == 1)
        // A mild afternoon does not re-arm the frost that is still forecast for the night.
        fixture.advance(hours: 7)
        fixture.notifier.process([frost(.normal, "current")])
        fixture.notifier.process([frost(.warning, "forecast")])
        #expect(fixture.posted.count == 1)
        // The frost arrives.
        fixture.notifier.process([frost(.warning, "current"), frost(.warning, "forecast")])
        #expect(fixture.posted.count == 1)
        // It gets worse than forecast.
        fixture.notifier.process([frost(.critical, "current")])
        #expect(fixture.posted.map { $0.level } == [.warning, .critical])
    }

    @Test func theStateSurvivesANewNotifier() {
        let fixture = Fixture()
        fixture.notifier.process([self.assessment(.warning)])
        let relaunched = WarningNotifier(
            defaults: fixture.defaults, now: { fixture.now }, isLocationMeasured: { true }, post: { fixture.posted.append($0) })
        relaunched.process([self.assessment(.warning)])
        #expect(fixture.posted.count == 1)
    }

    @Test func keysNotSeenForAWeekAreForgotten() {
        let fixture = Fixture()
        fixture.notifier.process([self.assessment(.warning, key: "hazard.old", family: .hazards)])
        fixture.advance(hours: 24 * 8)
        fixture.notifier.process([self.assessment(.normal)])
        #expect(Set(fixture.notifier.load().keys) == ["radiation.total.kenn"])
    }
}
