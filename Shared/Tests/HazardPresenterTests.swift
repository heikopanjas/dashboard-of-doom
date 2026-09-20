import DoomKitLocation
import DoomKitProcess
import DoomKitServices
import Foundation
import Testing

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct HazardPresenterTests {
    private static let hkw = Location(latitude: 52.51889, longitude: 13.36528)

    private static func hazard(_ id: String, sent: Date) -> Hazard {
        return Hazard(
            id: id, feed: .dwd, event: nil, headline: id, description: "", instruction: nil, severity: .moderate,
            sent: sent, expires: nil, areaDescription: "Berlin", location: Self.hkw, distance: 0, placemark: nil)
    }

    /// Fetch calls suspend until the test resumes them, so ordering is under test control.
    @MainActor private final class Fixture {
        let suite = "HazardPresenterTests.\(UUID())"
        let defaults: UserDefaults
        var registrations: [TimeInterval] = []
        var removals = 0
        var fetches: [Location] = []
        var pending: [CheckedContinuation<Result<[Hazard], Error>, Never>] = []
        var now: Date
        var presenter: HazardPresenter!

        init(enabled: Bool? = nil) throws {
            self.defaults = try #require(UserDefaults(suiteName: self.suite))
            self.now = Date(timeIntervalSince1970: 1_800_000_000)
            if let enabled { self.defaults.set(enabled, forKey: "showHazards") }
            self.presenter = HazardPresenter(
                defaults: self.defaults,
                register: { [weak self] _, interval in self?.registrations.append(interval) },
                remove: { [weak self] _ in self?.removals += 1 },
                fetch: { [weak self] location in
                    guard let self else { return [] }
                    self.fetches.append(location)
                    let result = await withCheckedContinuation { continuation in self.pending.append(continuation) }
                    return try result.get()
                },
                now: { [weak self] in self?.now ?? Date.now })
        }

        deinit {
            self.defaults.removePersistentDomain(forName: self.suite)
        }

        func refresh(at location: Location = HazardPresenterTests.hkw) -> Task<Void, Never> {
            let presenter = self.presenter!
            return Task { await presenter.refreshData(location: location) }
        }

        func resume(with result: Result<[Hazard], Error>) async {
            while self.pending.isEmpty { await Task.yield() }
            self.pending.removeFirst().resume(returning: result)
        }
    }

    private struct Boom: Error {}

    @Test func registersWithFifteenMinuteFallback() throws {
        let fixture = try Fixture()
        #expect(fixture.registrations == [15])
        #expect(fixture.presenter.isEnabled == true)
        #expect(fixture.presenter.state == .loading)
    }

    @Test func emptyFetchShowsAllClear() async throws {
        let fixture = try Fixture()
        let task = fixture.refresh()
        await fixture.resume(with: .success([]))
        await task.value
        #expect(fixture.presenter.hazards.isEmpty)
        #expect(fixture.presenter.state == .loaded)
        #expect(fixture.presenter.timestamp == fixture.now)
    }

    @Test func failureKeepsLastListAndReportsFailed() async throws {
        let fixture = try Fixture()
        let first = fixture.refresh()
        await fixture.resume(with: .success([Self.hazard("storm", sent: fixture.now)]))
        await first.value
        let loadedAt = fixture.presenter.timestamp
        fixture.now = fixture.now.addingTimeInterval(1000)
        let second = fixture.refresh(at: Location(latitude: 52.6, longitude: 13.5))
        await fixture.resume(with: .failure(Boom()))
        await second.value
        #expect(fixture.presenter.hazards.map(\.id) == ["storm"])
        #expect(fixture.presenter.timestamp == loadedAt)
        if case .failed = fixture.presenter.state {} else { Issue.record("expected a failed state") }
    }

    @Test func disablingRemovesRegistrationAndSkipsFetch() async throws {
        let fixture = try Fixture()
        let first = fixture.refresh()
        await fixture.resume(with: .success([Self.hazard("storm", sent: fixture.now)]))
        await first.value
        fixture.defaults.set(false, forKey: "showHazards")
        NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: fixture.defaults)
        #expect(fixture.removals == 1)
        #expect(fixture.presenter.isEnabled == false)
        await fixture.presenter.refreshData(location: Self.hkw)
        #expect(fixture.fetches.count == 1)
        #expect(fixture.presenter.hazards.map(\.id) == ["storm"])
    }

    @Test func staleGenerationAndCancelledTaskCannotPublish() async throws {
        let fixture = try Fixture()
        let first = fixture.refresh()
        while fixture.pending.count < 1 { await Task.yield() }
        let second = fixture.refresh()
        while fixture.pending.count < 2 { await Task.yield() }
        fixture.pending[0].resume(returning: .success([Self.hazard("stale", sent: fixture.now)]))
        await first.value
        #expect(fixture.presenter.hazards.isEmpty)
        fixture.pending[1].resume(returning: .success([]))
        await second.value
        #expect(fixture.presenter.state == .loaded)
        #expect(fixture.presenter.hazards.isEmpty)
        fixture.pending.removeAll()

        let cancelled = fixture.refresh()
        while fixture.pending.isEmpty { await Task.yield() }
        cancelled.cancel()
        fixture.pending.removeFirst().resume(returning: .success([Self.hazard("late", sent: fixture.now)]))
        await cancelled.value
        #expect(fixture.presenter.hazards.isEmpty)
    }

    @Test func failureCooldownSkipsNearbyRetriesUntilItExpires() async throws {
        let fixture = try Fixture()
        let failing = fixture.refresh()
        await fixture.resume(with: .failure(Boom()))
        await failing.value
        #expect(fixture.fetches.count == 1)

        fixture.now = fixture.now.addingTimeInterval(60)
        await fixture.presenter.refreshData(location: Location(latitude: 52.5195, longitude: 13.3660))
        #expect(fixture.fetches.count == 1)

        fixture.now = fixture.now.addingTimeInterval(HazardPresenter.failureCooldown)
        let retry = fixture.refresh()
        await fixture.resume(with: .success([]))
        await retry.value
        #expect(fixture.fetches.count == 2)
        #expect(fixture.presenter.state == .loaded)
    }
}
