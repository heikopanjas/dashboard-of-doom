import DoomKitLocation
import Foundation
import Testing

@MainActor @Suite struct SimulationPresenterTests {
    private static let hkw = Location(latitude: 52.51889, longitude: 13.36528)
    private static let dresden = Location(latitude: 51.054, longitude: 13.738)
    private static let büsum = Location(latitude: 54.1283, longitude: 8.8589)

    @Test func startingSimulatesThePlaceUnderItsName() {
        // Never started, so no real fix arrives.
        let manager = LocationManager(fallback: Self.hkw)
        let presenter = SimulationPresenter(location: manager)
        #expect(presenter.isSimulating == false)
        presenter.start(Self.dresden, name: "Dresden")
        #expect(presenter.isSimulating == true)
        #expect(presenter.placeName == "Dresden")
        #expect(manager.state.origin == .simulated)
        #expect(manager.state.location == Self.dresden)
        // One place follows another without a stop in between.
        presenter.start(Self.büsum, name: "Büsum")
        #expect(presenter.placeName == "Büsum")
        #expect(manager.state.location == Self.büsum)
    }

    @Test func stoppingReturnsToTheRealLocation() {
        let manager = LocationManager(fallback: Self.hkw)
        let presenter = SimulationPresenter(location: manager)
        presenter.start(Self.dresden, name: "Dresden")
        presenter.stop()
        #expect(presenter.isSimulating == false)
        #expect(presenter.placeName == nil)
        #expect(manager.isSimulating == false)
        #expect(manager.state.location == Self.hkw)
        #expect(manager.state.origin == .fallback)
    }
}
