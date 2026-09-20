import CoreGraphics
import DoomKitLocation
import Foundation
import Testing

@Suite @MainActor struct PointOfInterestTests {
    private static let berlin = Location(latitude: 52.51889, longitude: 13.36528)

    private final class Clock {
        var date = Date(timeIntervalSince1970: 10000)
    }

    private actor Server {
        var calls = 0
        var active = 0
        var maximum = 0
        var failures = false
        var blocked = false
        var blockedCategories: Set<PointOfInterestCategory> = []
        var waiters: [CheckedContinuation<Void, Never>] = []

        func configure(failures: Bool = false, blocked: Bool = false, blockedCategories: Set<PointOfInterestCategory> = []) {
            self.blockedCategories = blockedCategories
            self.failures = failures
            self.blocked = blocked
        }

        func release() {
            self.blockedCategories = []
            self.blocked = false
            let waiters = self.waiters
            self.waiters = []
            for waiter in waiters { waiter.resume() }
        }

        func fetch(_ category: PointOfInterestCategory, location: Location) async throws -> [PointOfInterest] {
            self.calls += 1
            self.active += 1
            self.maximum = max(self.maximum, self.active)
            defer { self.active -= 1 }
            if self.blocked == true || self.blockedCategories.contains(category) == true {
                await withCheckedContinuation { self.waiters.append($0) }
            }
            else {
                try await Task.sleep(for: .milliseconds(5))
            }
            if self.failures == true { throw URLError(.notConnectedToInternet) }
            return [PointOfInterest(category: category, elementType: "node", elementID: Int64(self.calls), name: nil, location: location)]
        }
    }

    private func eventually(_ condition: () async -> Bool) async throws {
        for _ in 0 ..< 2000 {
            if await condition() == true { return }
            try await Task.sleep(for: .milliseconds(1))
        }
        Issue.record("Timed out waiting for asynchronous POI state")
        throw URLError(.timedOut)
    }

    private func makePresenter(server: Server, clock: Clock) throws -> (PointOfInterestPresenter, String) {
        let suite = "POITests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        let presenter = PointOfInterestPresenter(
            defaults: defaults,
            fetch: { category, location in return try await server.fetch(category, location: location) },
            now: { clock.date }, sleep: { try await Task.sleep(for: .seconds(36000)) })
        presenter.start(updates: AsyncStream { $0.finish() })
        return (presenter, suite)
    }

    @Test func decodeStableUnnamedAndMalformedElements() throws {
        let data = Data(
            #"{"elements":[{"type":"node","id":1,"lat":52.5,"lon":13.3},{"type":"node","id":1,"lat":52.5,"lon":13.3},{"type":"way","id":1,"center":{"lat":52.6,"lon":13.4},"tags":{"name":"Hospital"}},{"type":"node","id":2,"lat":91,"lon":0},{"type":"node","id":3,"lat":0,"lon":181},{"type":"node","id":4},{"type":"relation","id":5,"lat":0,"lon":0}]}"#
                .utf8)
        let points = try PointOfInterestController.decode(data, category: .hospitals)
        #expect(points.count == 2)
        #expect(points[0].name == nil)
        #expect(points[1].name == "Hospital")
        #expect(points[0].id != points[1].id)
        #expect(try PointOfInterestController.decode(data, category: .hospitals) == points)
        #expect(throws: (any Error).self) { try PointOfInterestController.decode(Data("{}".utf8), category: .stores) }
        #expect(try PointOfInterestController.decode(Data(#"{"elements":[]}"#.utf8), category: .stores).isEmpty)
    }

    @Test func projectionPreservesCoincidentPointsAndFiltersInvalidCoordinates() {
        let points = (0 ..< 10000).map { index in
            PointOfInterest(category: .stores, elementType: "node", elementID: Int64(index), name: nil, location: Self.berlin)
        }
        let inputs = points.map(PointOfInterestProjection.Input.init)
        let viewport = CGRect(x: 0, y: 0, width: 500, height: 400)
        let result = PointOfInterestProjection.project(inputs, viewport: viewport) { _ in CGPoint(x: 100, y: 100) }
        #expect(result.symbols.count == 10000)
        #expect(Set(result.symbols.map(\.id)).count == 10000)
        #expect(PointOfInterestProjection.project(inputs, viewport: viewport) { _ in nil }.symbols.isEmpty)
        #expect(PointOfInterestProjection.project(inputs, viewport: viewport) { _ in CGPoint(x: CGFloat.nan, y: 0) }.symbols.isEmpty)
        #expect(PointOfInterestProjection.project(inputs, viewport: viewport) { _ in CGPoint(x: 510, y: 0) }.symbols.isEmpty)
        #expect(PointOfInterestProjection.project(inputs, viewport: viewport) { _ in CGPoint(x: -4, y: 0) }.symbols.count == 10000)
        #expect(
            PointOfInterestProjection.project(inputs, viewport: CGRect(x: 0, y: 0, width: 50, height: 50)) { _ in CGPoint(x: 100, y: 100) }.symbols
                .isEmpty)
        let renamed = PointOfInterest(category: .stores, elementType: "node", elementID: 0, name: "New text", location: Self.berlin)
        #expect(PointOfInterestProjection.Input(renamed) == inputs[0])
        let moved = PointOfInterest(
            category: .stores, elementType: "node", elementID: 0, name: nil, location: Location(latitude: 53, longitude: 13))
        #expect(PointOfInterestProjection.Input(moved) != inputs[0])
        #expect(Array(inputs.dropFirst()) != inputs)
    }

    @Test func cacheExpiryMovementAndSettings() async throws {
        let server = Server()
        let clock = Clock()
        let (presenter, suite) = try self.makePresenter(server: server, clock: clock)
        defer {
            presenter.stop()
            UserDefaults.standard.removePersistentDomain(forName: suite)
        }
        presenter.updateLocation(Self.berlin)
        try await self.eventually { presenter.points.count == 5 }
        #expect(await server.calls == 5)
        #expect(await server.maximum <= 2)
        presenter.refreshIfNeeded()
        presenter.updateLocation(Location(latitude: Self.berlin.latitude + 0.001, longitude: Self.berlin.longitude))
        #expect(await server.calls == 5)
        presenter.setCategory(.stores, enabled: false)
        #expect(presenter.points.count == 4)
        presenter.setCategory(.stores, enabled: true)
        #expect(presenter.points.count == 5)
        presenter.setEnabled(false)
        #expect(presenter.points.isEmpty)
        presenter.setEnabled(true)
        #expect(presenter.points.count == 5)
        #expect(await server.calls == 5)
        clock.date += 3600
        presenter.refreshIfNeeded()
        try await self.eventually {
            let calls = await server.calls
            let active = await server.active
            return calls == 10 && active == 0
        }
        let far = Location(latitude: 53, longitude: 13)
        presenter.updateLocation(far)
        #expect(presenter.points.isEmpty)
        try await self.eventually { presenter.points.count == 5 && presenter.points.allSatisfy { $0.location == far } }
        #expect(await server.calls == 15)
    }

    @Test func showsAnyPlacesNeedsTheMasterSwitchAndOneCategory() throws {
        let suite = "POITests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        let presenter = PointOfInterestPresenter(defaults: defaults, fetch: { _, _ in return [] })
        #expect(presenter.showsAnyPlaces == true)
        for category in PointOfInterestCategory.allCases { presenter.setCategory(category, enabled: false) }
        // Master on but nothing selected draws no pins, so the labels must not stay opaque.
        #expect(presenter.showsAnyPlaces == false)
        presenter.setCategory(.pharmacies, enabled: true)
        #expect(presenter.showsAnyPlaces == true)
        presenter.setEnabled(false)
        #expect(presenter.showsAnyPlaces == false)
        presenter.setCategory(.hospitals, enabled: true)
        #expect(presenter.showsAnyPlaces == false)
    }

    @Test func fetchingWhileHiddenKeepsAllPointsAndFiltersOnlyTheMap() async throws {
        let server = Server()
        let clock = Clock()
        let suite = "POITests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.set(false, forKey: "showPlaces")
        defaults.set(false, forKey: PointOfInterestCategory.stores.preferenceKey)
        let presenter = PointOfInterestPresenter(
            defaults: defaults,
            fetch: { category, location in return try await server.fetch(category, location: location) },
            now: { clock.date }, sleep: { try await Task.sleep(for: .seconds(36000)) },
            fetchesWhenHidden: true)
        presenter.start(updates: AsyncStream { $0.finish() })
        defer {
            presenter.stop()
            UserDefaults.standard.removePersistentDomain(forName: suite)
        }
        presenter.updateLocation(Self.berlin)
        // Every category loads although the master switch and one category are off.
        try await self.eventually { presenter.allPoints.count == 5 }
        #expect(await server.calls == 5)
        #expect(presenter.points.isEmpty)
        presenter.setEnabled(true)
        #expect(presenter.points.count == 4)
        #expect(presenter.allPoints.count == 5)
        presenter.setCategory(.stores, enabled: true)
        #expect(presenter.points.count == 5)
        // The switches never cause another fetch; everything was already cached.
        #expect(await server.calls == 5)
    }

    @Test func failuresRetainCacheAndRetryAfterFiveMinutes() async throws {
        let server = Server()
        let clock = Clock()
        let (presenter, suite) = try self.makePresenter(server: server, clock: clock)
        defer {
            presenter.stop()
            UserDefaults.standard.removePersistentDomain(forName: suite)
        }
        presenter.updateLocation(Self.berlin)
        try await self.eventually { presenter.points.count == 5 }
        let cached = presenter.points
        await server.configure(failures: true)
        clock.date += 3600
        presenter.refreshIfNeeded()
        try await self.eventually {
            let calls = await server.calls
            let active = await server.active
            return calls == 10 && active == 0
        }
        // Allow the main actor to publish the completed batch before checking cooldown.
        try await Task.sleep(for: .milliseconds(10))
        #expect(presenter.points == cached)
        presenter.refreshIfNeeded()
        #expect(await server.calls == 10)
        await server.configure()
        clock.date += 300
        presenter.refreshIfNeeded()
        try await self.eventually {
            let calls = await server.calls
            let active = await server.active
            return calls == 15 && active == 0 && presenter.points != cached
        }
        #expect(await server.calls == 15)
    }

    @Test func cancelledGenerationsCannotPublishOrOverlap() async throws {
        let server = Server()
        await server.configure(blocked: true)
        let (presenter, suite) = try self.makePresenter(server: server, clock: Clock())
        defer {
            presenter.stop()
            UserDefaults.standard.removePersistentDomain(forName: suite)
        }
        presenter.updateLocation(Self.berlin)
        try await self.eventually { await server.calls == 2 }
        presenter.setEnabled(false)
        let far = Location(latitude: 53, longitude: 13)
        presenter.updateLocation(far)
        presenter.setEnabled(true)
        #expect(await server.calls == 2)
        await server.release()
        try await self.eventually { presenter.points.count == 5 }
        #expect(presenter.points.allSatisfy { $0.location == far })
        #expect(await server.maximum <= 2)
        await server.configure(blocked: true)
        presenter.updateLocation(Self.berlin)
        try await self.eventually { await server.active == 2 }
        presenter.stop()
        await server.release()
        try await self.eventually { await server.active == 0 }
        #expect(presenter.points.isEmpty)
        let calls = await server.calls
        presenter.refreshIfNeeded()
        #expect(await server.calls == calls)
    }
    @Test func fallbackStartupTimerAndPersistedPreferences() async throws {
        let suite = "POITests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let server = Server()
        let clock = Clock()
        let ticks = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let presenter = PointOfInterestPresenter(
            defaults: defaults,
            fetch: { category, location in return try await server.fetch(category, location: location) },
            now: { clock.date },
            sleep: {
                var iterator = ticks.stream.makeAsyncIterator()
                guard await iterator.next() != nil else { throw CancellationError() }
            })
        defer {
            presenter.stop()
            ticks.continuation.finish()
        }
        #expect(presenter.isEnabled)
        #expect(presenter.categories.count == 5)
        presenter.setCategory(.stores, enabled: false)
        let locations = LocationManager(fallback: Self.berlin)
        presenter.start(updates: locations.updates())
        presenter.start(updates: AsyncStream { $0.finish() })
        try await self.eventually { presenter.points.count == 4 }
        #expect(await server.calls == 4)
        presenter.setCategory(.stores, enabled: true)
        try await self.eventually { presenter.points.count == 5 }
        #expect(await server.calls == 5)
        clock.date += 3600
        ticks.continuation.yield(())
        try await self.eventually { await server.calls == 10 }
        presenter.setEnabled(false)
        let restored = PointOfInterestPresenter(defaults: defaults, fetch: { _, _ in return [] })
        #expect(restored.isEnabled == false)
        #expect(restored.categories.count == 5)
        presenter.stop()
        clock.date += 3600
        ticks.continuation.yield(())
        #expect(presenter.points.isEmpty)
    }

    @Test func publishesSuccessfulCategoriesWhileAnotherIsPending() async throws {
        let server = Server()
        await server.configure(blockedCategories: [.hospitals])
        let (presenter, suite) = try self.makePresenter(server: server, clock: Clock())
        defer {
            presenter.stop()
            UserDefaults.standard.removePersistentDomain(forName: suite)
        }
        presenter.updateLocation(Self.berlin)
        try await self.eventually { presenter.points.count == 4 }
        #expect(presenter.points.contains { $0.category == .hospitals } == false)
        #expect(await server.active == 1)
        await server.release()
        try await self.eventually { presenter.points.count == 5 }
        #expect(await server.calls == 5)
        #expect(await server.maximum <= 2)
    }

}
