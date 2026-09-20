import DoomKitLocation
import DoomKitNetwork
import Foundation
import Testing
@testable import DoomKitProcess

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct ProcessCoordinatorTests {
    private final class LocationSource: ProcessLocationSource {
        var state = LocationManager(fallback: Location(latitude: 52, longitude: 13)).state
        var continuation: AsyncStream<LocationState>.Continuation?
        var starts = 0
        var stops = 0
        func updates() -> AsyncStream<LocationState> {
            let pair = AsyncStream.makeStream(of: LocationState.self)
            self.continuation = pair.continuation
            pair.continuation.yield(self.state)
            return pair.stream
        }
        func start() { self.starts += 1 }
        func stop() { self.stops += 1; self.continuation?.finish() }
        func measure(_ latitude: Double) {
            self.state.location = Location(latitude: latitude, longitude: 13)
            self.state.origin = .measured
            self.continuation?.yield(self.state)
        }
    }
    @MainActor private final class NetworkSource: ProcessNetworkSource {
        let gate = AsyncStream.makeStream(of: Void.self)
        var starts = 0
        var timeout: Duration?
        var expires = false
        func startMonitoring() async { self.starts += 1 }
        func updates() async -> AsyncStream<NetworkState> { return AsyncStream { _ in } }
        func waitForConnection(timeout: Duration) async throws {
            self.timeout = timeout
            for await _ in self.gate.stream { break }
            try Task.checkCancellation()
            if self.expires == true { throw NetworkError.timeout }
        }
    }
    private final class Subscriber: ProcessPresenter, ProcessRefreshable {
        let events = AsyncStream.makeStream(of: Location.self)
        var values: [Location] = []
        func refreshData(location: Location) async {
            self.values.append(location)
            self.events.continuation.yield(location)
        }
    }

    @Test func startupLocationSettingsStopAndRestart() async {
        let source = LocationSource()
        let network = NetworkSource()
        let clock = CoordinatorTestClock()
        let coordinator = ProcessCoordinator(locationSource: source, networkSource: network, clock: clock.clock)
        let subscriber = Subscriber(coordinator: coordinator)
        var events = subscriber.events.stream.makeAsyncIterator()
        coordinator.add(subscriber: subscriber, timeout: 1)
        #expect(source.starts == 0)
        #expect(network.starts == 0)
        #expect(coordinator.scheduler.isRunning == false)
        #expect(subscriber.values.isEmpty == true)
        coordinator.start()
        coordinator.start()
        #expect(source.starts == 1)
        #expect(await events.next() == source.state.location)
        source.measure(53)
        #expect(await events.next()?.latitude == 53)
        #expect(subscriber.values.count == 2)
        network.gate.continuation.yield(())
        await clock.waitForSleep()
        #expect(network.timeout == .seconds(30))
        #expect(coordinator.scheduler.isRunning == true)
        source.measure(54)
        // The next clock handshake runs after the queued location update.
        clock.advance(.seconds(1))
        await clock.waitForSleep()
        #expect(subscriber.values.count == 2)
        coordinator.refreshSubscription(subscriber: subscriber)
        #expect(await events.next()?.latitude == 54)
        clock.advance(.seconds(60))
        #expect(await events.next()?.latitude == 54)
        coordinator.stop()
        #expect(coordinator.scheduler.isRunning == false)
        #expect(coordinator.scheduler.refresh(id: subscriber.id) == nil)
        coordinator.start()
        #expect(await events.next()?.latitude == 54)
        #expect(source.starts == 2)
        coordinator.stop()
    }

    @Test func everyMovementRefreshesAndDuplicateCoordinatesDoNot() async {
        let source = LocationSource()
        source.state.location = Location(latitude: 52.51889, longitude: 13.36528)
        let network = NetworkSource()
        let clock = CoordinatorTestClock()
        let coordinator = ProcessCoordinator(locationSource: source, networkSource: network, clock: clock.clock, locationRefreshPolicy: .everyMovement)
        defer { coordinator.stop() }
        let subscriber = Subscriber(coordinator: coordinator)
        coordinator.add(subscriber: subscriber, timeout: 30)
        var events = subscriber.events.stream.makeAsyncIterator()
        coordinator.start()
        #expect(await events.next() == source.state.location)
        source.measure(52.52)
        #expect(await events.next()?.latitude == 52.52)
        source.measure(52.53)
        #expect(await events.next()?.latitude == 52.53)
        network.gate.continuation.yield(())
        await clock.waitForSleep()
        source.measure(52.53)
        clock.advance(.seconds(1))
        await clock.waitForSleep()
        #expect(subscriber.values.count == 3)
        coordinator.remove(subscriber: subscriber)
        source.measure(52.54)
        clock.advance(.seconds(60))
        await clock.waitForSleep()
        #expect(subscriber.values.count == 3)
    }

    @Test func offlineTimeoutStartsScheduling() async {
        let source = LocationSource()
        let network = NetworkSource()
        network.expires = true
        let clock = CoordinatorTestClock()
        let coordinator = ProcessCoordinator(locationSource: source, networkSource: network, clock: clock.clock)
        coordinator.start()
        network.gate.continuation.yield(())
        await clock.waitForSleep()
        #expect(network.timeout == .seconds(30))
        #expect(coordinator.scheduler.isRunning == true)
        #expect(coordinator.scheduler.isReady == true)
        coordinator.stop()
    }

    @Test func stopCancelsInFlightRefresh() async {
        let source = LocationSource()
        let network = NetworkSource()
        let clock = CoordinatorTestClock()
        let coordinator = ProcessCoordinator(locationSource: source, networkSource: network)
        coordinator.start()
        let id = coordinator.scheduler.register(interval: .seconds(60)) { _ in
            try? await clock.sleep()
        }
        await clock.waitForSleep()
        let task = coordinator.scheduler.refresh(id: id)
        coordinator.stop()
        #expect(task?.isCancelled == true)
        await task?.value
    }

    @Test func cleanupAndWeakCoordinatorOwnership() async {
        let source = LocationSource()
        let network = NetworkSource()
        var coordinator: ProcessCoordinator? = ProcessCoordinator(locationSource: source, networkSource: network)
        var subscriber: Subscriber? = Subscriber(coordinator: coordinator)
        if let subscriber { coordinator?.add(subscriber: subscriber, timeout: 1) }
        #expect(coordinator?.scheduler.registrationCount == 1)
        subscriber = nil
        #expect(coordinator?.scheduler.registrationCount == 0)
        let survivor = Subscriber(coordinator: coordinator)
        weak let weakCoordinator = coordinator
        coordinator = nil
        #expect(weakCoordinator == nil)
        #expect(survivor.sensor == nil)
    }

    @Test func stoppedStartupCannotRestartScheduler() async {
        let source = LocationSource()
        let network = NetworkSource()
        let coordinator = ProcessCoordinator(locationSource: source, networkSource: network)
        coordinator.start()
        coordinator.stop()
        network.gate.continuation.finish()
        // Await queued startup work through an independent main-actor task.
        await Task { @MainActor in }.value
        #expect(coordinator.scheduler.isRunning == false)
        #expect(source.stops == 1)
    }
}
