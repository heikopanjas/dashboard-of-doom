import Foundation
import Testing

@testable import DoomKitLocation

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct LocationSimulationTests {
    private final class Provider: LocationProvider {
        var onUpdate: (@MainActor (LocationProviderUpdate) -> Void)?
        func start() {}
        func stop() {}
        func send(_ location: Location? = nil, authorization: LocationState.Authorization = .authorized) {
            self.onUpdate?(.init(location: location, authorization: authorization))
        }
    }

    private let hkw = Location(latitude: 52.51889, longitude: 13.36528)
    private let dresden = Location(latitude: 51.054, longitude: 13.738)

    @Test func aSimulatedPlaceReplacesTheLocationAndRealFixesWaitForItsEnd() async {
        let provider = Provider()
        let manager = LocationManager(fallback: self.hkw, provider: provider)
        var updates = manager.updates().makeAsyncIterator()
        _ = await updates.next()
        manager.start()
        _ = await updates.next()
        provider.send(self.hkw)
        _ = await updates.next()
        #expect(manager.isSimulating == false)

        manager.simulate(self.dresden)
        #expect(manager.isSimulating == true)
        #expect(manager.state.location == self.dresden)
        #expect(manager.state.origin == .simulated)
        let simulated = await updates.next()
        #expect(simulated?.origin == .simulated)

        // A real fix far away neither moves the location nor ends the simulation; authorization still follows.
        let moved = Location(latitude: 52.53, longitude: 13.36528)
        provider.send(moved, authorization: .authorized)
        #expect(manager.state.location == self.dresden)
        #expect(manager.state.origin == .simulated)
        provider.send(nil, authorization: .denied)
        #expect(manager.state.authorization == .denied)

        // Ending returns to the last real fix, the one received while simulating.
        manager.endSimulation()
        #expect(manager.isSimulating == false)
        #expect(manager.state.location == moved)
        #expect(manager.state.origin == .measured)
        manager.stop()
    }

    @Test func aSimulationWithoutARealFixEndsAtTheFallback() {
        let manager = LocationManager(fallback: self.hkw, provider: Provider())
        manager.simulate(self.dresden)
        // A second place replaces the first, however near.
        let near = Location(latitude: 51.0541, longitude: 13.738)
        manager.simulate(near)
        #expect(manager.state.location == near)
        manager.endSimulation()
        #expect(manager.state.location == self.hkw)
        #expect(manager.state.origin == .fallback)
        // Ending twice changes nothing.
        manager.endSimulation()
        #expect(manager.state.origin == .fallback)
    }

    @Test func theStreamsStayOpenThroughASimulation() async {
        let manager = LocationManager(fallback: self.hkw, provider: Provider())
        var updates = manager.updates().makeAsyncIterator()
        #expect(await updates.next()?.origin == .fallback)
        manager.simulate(self.dresden)
        #expect(await updates.next()?.location == self.dresden)
        manager.endSimulation()
        #expect(await updates.next()?.location == self.hkw)
    }

    @Test func stoppingEndsTheSimulation() {
        let provider = Provider()
        let manager = LocationManager(fallback: self.hkw, provider: provider)
        manager.start()
        provider.send(self.hkw)
        manager.simulate(self.dresden)
        manager.stop()
        #expect(manager.isSimulating == false)
        #expect(manager.state.location == self.hkw)
        #expect(manager.state.origin == .measured)
    }
}
