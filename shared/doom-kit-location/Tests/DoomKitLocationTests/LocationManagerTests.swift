import Foundation
import Testing

@testable import DoomKitLocation

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct LocationManagerTests {
    private final class Provider: LocationProvider {
        var onUpdate: (@MainActor (LocationProviderUpdate) -> Void)?
        var starts = 0
        var stops = 0
        func start() { self.starts += 1 }
        func stop() { self.stops += 1 }
        func send(
            _ location: Location? = nil, authorization: LocationState.Authorization = .authorized,
            failure: LocationState.Failure? = nil
        ) {
            self.onUpdate?(.init(location: location, authorization: authorization, failure: failure))
        }
    }

    private let fallback = Location(latitude: 0, longitude: 0)

    @Test func replayFilteringAndProviderSubstitution() async {
        let provider = Provider()
        let manager = LocationManager(fallback: self.fallback, provider: provider)
        #expect(provider.starts == 0)
        var first = manager.updates().makeAsyncIterator()
        var second = manager.updates().makeAsyncIterator()
        #expect(await first.next()?.origin == .fallback)
        #expect(await second.next()?.location == self.fallback)
        manager.start()
        provider.send(self.fallback)
        #expect(manager.state.origin == .measured)
        let near = Location(latitude: 0, longitude: 0.0008)
        provider.send(near)
        #expect(manager.state.location == self.fallback)
        let far = Location(latitude: 0, longitude: 0.001)
        provider.send(far)
        #expect(await first.next()?.location == far)
        #expect(await second.next()?.location == far)
        manager.stop()
    }

    @Test func hkwMovementFilterAndAuthorizationScope() {
        let hkw = Location(latitude: 52.51889, longitude: 13.36528)
        let provider = Provider()
        let manager = LocationManager(fallback: hkw, provider: provider)
        manager.start()
        defer { manager.stop() }
        provider.send(hkw)
        provider.send(Location(latitude: 52.519, longitude: 13.36528))
        #expect(manager.state.location == hkw)
        let moved = Location(latitude: 52.52, longitude: 13.36528)
        provider.send(moved)
        #expect(manager.state.location == moved)
        provider.onUpdate?(.init(authorization: .authorized, authorizationScope: .whenInUse))
        #expect(manager.state.authorizationScope == .whenInUse)
        provider.onUpdate?(.init(authorization: .authorized, authorizationScope: .always))
        #expect(manager.state.authorizationScope == .always)
        provider.send(authorization: .denied)
        #expect(manager.state.authorizationScope == .unknown)
        #expect(manager.state.location == moved)
    }

    @Test func authorizationFailureShutdownAndRestart() async {
        let provider = Provider()
        let manager = LocationManager(fallback: self.fallback, provider: provider)
        manager.start()
        let obsolete = provider.onUpdate
        var stream = manager.updates().makeAsyncIterator()
        provider.send(authorization: .denied)
        #expect(await stream.next()?.failure == .denied)
        provider.send(failure: .unavailable)
        #expect(manager.state.failure == .unavailable)
        provider.send(self.fallback)
        #expect(manager.state.failure == nil)
        manager.stop()
        #expect(await stream.next()?.tracking == .stopped)
        #expect(await stream.next() == nil)
        manager.start()
        obsolete?(.init(location: Location(latitude: 10, longitude: 10), authorization: .authorized))
        #expect(manager.state.location == self.fallback)
        #expect(provider.starts == 2)
        manager.stop()
    }

    @Test func independentCancellationAndCleanup() async {
        let provider = Provider()
        var manager: LocationManager? = LocationManager(fallback: self.fallback, provider: provider)
        let cancelledStream = manager?.updates()
        let task = Task {
            if let cancelledStream {
                for await _ in cancelledStream {}
            }
        }
        task.cancel()
        await task.value
        var other = manager?.updates().makeAsyncIterator()
        #expect(await other?.next()?.origin == .fallback)
        manager?.start()
        provider.send(self.fallback)
        #expect(await other?.next()?.origin == .measured)
        weak var weakManager = manager
        manager = nil
        #expect(weakManager == nil)
        #expect(provider.stops == 1)
        #expect(await other?.next() == nil)
    }

    @Test func geocodingAndValueSemantics() async throws {
        let place = GeocodedPlace(
            name: "Museum", postalCode: "10115", locality: "Berlin",
            subLocality: "Mitte", administrativeArea: "Berlin",
            subAdministrativeArea: "District")
        let service = GeocodingService { _ in return place }
        #expect(try await service.address(for: self.fallback) == "Museum, 10115 Berlin-Mitte")
        #expect(try await service.address(for: self.fallback, full: false) == "Berlin-Mitte")
        #expect(try await service.constituency(for: self.fallback) == "Berlin")
        #expect(GeocodedPlace(locality: "Town", subAdministrativeArea: "District").constituency == "District")
        #expect(GeocodedPlace(locality: "Town").constituency == "Town")
        #expect(Set([self.fallback, self.fallback]).count == 1)
        #expect(self.fallback.coordinate.latitude == 0)
        #expect(haversineDistance(location_0: self.fallback, location_1: self.fallback).value == 0)
    }
    @Test(arguments: [99.999, 100.0, 100.001])
    func strictMovementThreshold(meters: Double) {
        let provider = Provider()
        let manager = LocationManager(fallback: self.fallback, provider: provider)
        manager.start()
        provider.send(self.fallback)
        let point = Location(latitude: meters / 6_371_000 * 180 / .pi, longitude: 0)
        provider.send(point)
        #expect((manager.state.location == point) == (meters > 100))
        manager.stop()
    }

    @Test func geocodingFailureEmptyAndCancellation() async throws {
        let empty = GeocodingService { _ in return nil }
        #expect(try await empty.address(for: self.fallback) == nil)
        let failed = GeocodingService { _ in throw CancellationError() }
        await #expect(throws: CancellationError.self) {
            _ = try await failed.address(for: self.fallback)
        }
        let service = GeocodingService { _ in return GeocodedPlace(locality: "Berlin") }
        let task = Task { try await service.address(for: self.fallback) }
        task.cancel()
        do {
            _ = try await task.value
            Issue.record("Cancelled geocoding must not return a result")
        }
        catch is CancellationError {}
    }

}
