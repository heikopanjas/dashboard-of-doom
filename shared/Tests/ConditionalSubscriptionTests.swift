import DoomKitLocation
import DoomKitProcess
import Foundation
import Testing

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct ConditionalSubscriptionTests {
    nonisolated private static let sources = ["showCovid", SourcePreferences.waterKey, "showRadiation", "showParticles", SourcePreferences.pollsEnableKey]

    @MainActor private final class Fixture {
        let suite = "ConditionalSubscriptionTests.\(UUID())"
        let defaults: UserDefaults
        let key: String
        let scheduler: ProcessManager<Location>
        let clock: ManualClock
        var presenter: (any ProcessPresenter & ProcessRefreshable)?
        var registrations: [TimeInterval] = []
        var removals = 0
        var locations: [Location] = []
        var pending: [CheckedContinuation<[ProcessSensor], Never>] = []
        let starts = AsyncStream<Void>.makeStream()
        let finishes = AsyncStream<Void>.makeStream()

        init(key: String, enabled: Bool? = nil, interval: Int? = nil) throws {
            self.defaults = try #require(UserDefaults(suiteName: self.suite))
            self.key = key
            self.defaults.set(false, forKey: "showWeather")
            self.clock = ManualClock()
            self.scheduler = ProcessManager(context: Location(latitude: 52.51889, longitude: 13.36528), clock: self.clock.clock)
            if let enabled { self.defaults.set(enabled, forKey: key) }
            if let interval { self.defaults.set(interval, forKey: Self.intervalKey(key)) }
            let register: @MainActor (any ProcessRefreshable, TimeInterval) -> Void = { [weak self] subscriber, interval in
                guard let self else { return }
                self.registrations.append(interval)
                self.scheduler.register(id: subscriber.id, interval: .seconds(interval * 60)) { [weak self, weak subscriber] location in
                    await subscriber?.refreshData(location: location)
                    self?.finishes.continuation.yield(())
                }
            }
            let remove: @MainActor (UUID) -> Void = { [weak self] id in
                self?.removals += 1
                self?.scheduler.remove(id: id)
            }
            let fetch: @MainActor (Location) async throws -> [ProcessSensor] = { [weak self] location in
                guard let self else { return [] }
                self.locations.append(location)
                return await withCheckedContinuation { continuation in
                    self.pending.append(continuation)
                    self.starts.continuation.yield(())
                }
            }
            switch key {
                case "showCovid": self.presenter = CovidPresenter(defaults: self.defaults, register: register, remove: remove, fetch: fetch)
                case SourcePreferences.waterKey: self.presenter = LevelPresenter(defaults: self.defaults, register: register, remove: remove, fetch: fetch)
                case "showRadiation":
                    self.presenter = RadiationPresenter(defaults: self.defaults, register: register, remove: remove, fetch: fetch)
                case "showParticles": self.presenter = ParticlePresenter(defaults: self.defaults, register: register, remove: remove, fetch: fetch)
                case SourcePreferences.pollsEnableKey:
                    self.presenter = SurveyPresenter(defaults: self.defaults, register: register, remove: remove, fetch: fetch)
                case "weather": self.presenter = WeatherPresenter(defaults: self.defaults, register: register, fetch: fetch)
                default: self.presenter = ForecastPresenter(defaults: self.defaults, register: register, fetch: fetch)
            }
        }

        static func intervalKey(_ key: String) -> String {
            switch key {
                case "showCovid": return "covidRefreshInterval"
                case SourcePreferences.waterKey: return "levelRefreshInterval"
                case "showRadiation": return "radiationRefreshInterval"
                case "showParticles": return "particleRefreshInterval"
                case SourcePreferences.pollsEnableKey: return "surveyRefreshInterval"
                default: return "weatherRefreshInterval"
            }
        }

        func setEnabled(_ enabled: Bool) -> Void {
            self.defaults.set(enabled, forKey: self.key)
            self.notify()
        }

        func notify() -> Void {
            NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: self.defaults)
        }

        func complete(name: String) -> Void {
            self.pending.removeFirst().resume(returning: [
                ProcessSensor(
                    name: name, location: Location(latitude: 52.51889, longitude: 13.36528), placemark: "Berlin",
                    customData: nil, measurements: [:], timestamp: Date())
            ])
        }

        func close() -> Void {
            if let presenter = self.presenter { MapPresenter.shared.updateRegion(remove: presenter.id) }
            self.presenter = nil
            self.scheduler.shutdown()
            for continuation in self.pending { continuation.resume(returning: []) }
            self.pending.removeAll()
            self.clock.close()
            self.defaults.removePersistentDomain(forName: self.suite)
            self.starts.continuation.finish()
            self.finishes.continuation.finish()
        }
    }

    @MainActor private final class ManualClock {
        var now: Duration = .zero
        var sleeper: CheckedContinuation<Void, any Error>?
        let sleeps = AsyncStream<Void>.makeStream()
        var clock: ProcessClock {
            return ProcessClock(
                now: { self.now },
                sleep: { _ in
                    try await withCheckedThrowingContinuation { continuation in
                        self.sleeper = continuation
                        self.sleeps.continuation.yield(())
                    }
                })
        }
        func advance() -> Void {
            self.now += .seconds(24 * 60 * 60)
            let sleeper = self.sleeper
            self.sleeper = nil
            sleeper?.resume()
        }
        func close() -> Void {
            self.sleeper?.resume(throwing: CancellationError())
            self.sleeper = nil
            self.sleeps.continuation.finish()
        }
    }

    @Test func persistedChangesAreObservedWithoutAViewOrManualNotification() async throws {
        let suite = "ConditionalSubscriptionTests.automatic.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(false, forKey: "showCovid")
        let events = AsyncStream<Bool>.makeStream()
        var iterator = events.stream.makeAsyncIterator()
        let subscription = ConditionalSubscription(
            defaults: defaults, enableKey: "showCovid", intervalKey: "covidRefreshInterval", fallback: 360,
            register: { _ in events.continuation.yield(true) }, remove: { events.continuation.yield(false) })
        defaults.set(true, forKey: "showCovid")
        #expect(await iterator.next() == true)
        defaults.set(false, forKey: "showCovid")
        #expect(await iterator.next() == false)
        #expect(subscription.isEnabled == false)
        withExtendedLifetime(subscription) {}
        events.continuation.finish()
    }

    @Test(arguments: Self.sources)
    func disabledStartupAndAttemptsWithoutPopover(key: String) async throws {
        let fixture = try Fixture(key: key, enabled: false)
        defer { fixture.close() }
        let presenter = try #require(fixture.presenter)
        #expect(fixture.registrations.isEmpty == true)
        await presenter.refreshData(location: Location(latitude: 0, longitude: 0))
        fixture.scheduler.refreshAll()
        fixture.scheduler.updateContext(Location(latitude: 48, longitude: 11))
        fixture.scheduler.refreshAll()
        #expect(fixture.scheduler.refresh(id: presenter.id) == nil)
        for setting in ["nearestLevelSensor", "nearestParticleSensor", "electionPollScope", "showWeather"] {
            fixture.defaults.set(1, forKey: setting)
            fixture.notify()
        }
        var sleeps = fixture.clock.sleeps.stream.makeAsyncIterator()
        fixture.scheduler.start()
        await sleeps.next()
        fixture.clock.advance()
        await sleeps.next()
        #expect(fixture.locations.isEmpty == true)
        #expect(fixture.registrations.isEmpty == true)
    }

    @Test(arguments: Self.sources)
    func defaultsTransitionsCancellationAndRetention(key: String) async throws {
        let fixture = try Fixture(key: key, enabled: key == SourcePreferences.pollsEnableKey && SourcePreferences.pollsEnabledByDefault == false ? true : nil)
        defer { fixture.close() }
        let presenter = try #require(fixture.presenter)
        var starts = fixture.starts.stream.makeAsyncIterator()
        var finishes = fixture.finishes.stream.makeAsyncIterator()
        await starts.next()
        let fallback: TimeInterval = key == "showParticles" ? 30 : (["showCovid", SourcePreferences.pollsEnableKey].contains(key) == true ? 360 : 15)
        #expect(fixture.registrations == [fallback])
        fixture.complete(name: "retained")
        await finishes.next()
        #expect(presenter.sensor?.name == "retained")
        for _ in 0 ..< 5 { fixture.notify() }
        #expect(fixture.registrations.count == 1)
        fixture.scheduler.refreshAll()
        await starts.next()
        fixture.setEnabled(false)
        #expect(fixture.removals == 1)
        #expect(presenter.sensor?.name == "retained")
        let newLocation = Location(latitude: 48.1, longitude: 11.5)
        fixture.scheduler.updateContext(newLocation)
        fixture.setEnabled(true)
        await starts.next()
        #expect(fixture.locations.last == newLocation)
        // The cancelled fetch deliberately ignores cancellation and returns after re-enabling.
        fixture.complete(name: "stale")
        await finishes.next()
        #expect(presenter.sensor?.name == "retained")
        fixture.complete(name: "fresh")
        await finishes.next()
        #expect(presenter.sensor?.name == "fresh")
        fixture.setEnabled(false)
        await presenter.refreshData(location: newLocation)
        #expect(fixture.locations.count == 3)
        #expect(presenter.sensor?.name == "fresh")
    }

    @Test(arguments: Self.sources)
    func rapidTogglingUsesConfiguredIntervalAndCleansUp(key: String) async throws {
        let fixture = try Fixture(key: key, enabled: false, interval: 42)
        defer { fixture.close() }
        for _ in 0 ..< 4 {
            fixture.setEnabled(true)
            fixture.notify()
            fixture.setEnabled(false)
            fixture.notify()
        }
        #expect(fixture.registrations == Array(repeating: 42, count: 4))
        #expect(fixture.removals == 4)
        fixture.setEnabled(true)
        // No task has begun; releasing the presenter releases its helper and registration.
        weak let presenter = fixture.presenter
        fixture.presenter = nil
        #expect(presenter == nil)
        #expect(fixture.removals == 5)
        fixture.notify()
        #expect(fixture.registrations.count == 5)
    }

    @Test(arguments: ["weather", "forecast"])
    func weatherDisplayOffDoesNotStopScheduling(source: String) async throws {
        let fixture = try Fixture(key: source, interval: 7)
        defer { fixture.close() }
        fixture.defaults.set(false, forKey: "showWeather")
        fixture.notify()
        var starts = fixture.starts.stream.makeAsyncIterator()
        var finishes = fixture.finishes.stream.makeAsyncIterator()
        var sleeps = fixture.clock.sleeps.stream.makeAsyncIterator()
        await starts.next()
        fixture.complete(name: "first")
        await finishes.next()
        #expect(fixture.registrations == [7])
        fixture.scheduler.start()
        await sleeps.next()
        fixture.clock.advance()
        await starts.next()
        fixture.complete(name: "scheduled")
        await finishes.next()
        #expect(fixture.presenter?.sensor?.name == "scheduled")
        #expect(fixture.locations.count == 2)
    }
}
