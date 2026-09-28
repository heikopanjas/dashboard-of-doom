import DoomKitLocation
import Foundation
import Observation

/// Whether the app shows a simulated place, and which, in a form SwiftUI can observe: the location manager is not `@Observable`, so the
/// iOS SIM capsule and the simulation menu read this. Starting and stopping go through it, so the name travels with the place.
@MainActor @Observable final class SimulationPresenter {
    private(set) var isSimulating = false
    /// The simulated place's short name, "Dresden", while one is simulated.
    private(set) var placeName: String?
    @ObservationIgnored private let location: LocationManager
    @ObservationIgnored private var task: Task<Void, Never>?

    init(location: LocationManager = AppLocation.shared) {
        self.location = location
        self.isSimulating = location.isSimulating
        // Follows the manager, so a simulation ended there, as stopping the manager does, clears the capsule too.
        let updates = location.updates()
        self.task = Task { [weak self] in
            for await state in updates {
                guard let self else { return }
                self.isSimulating = state.origin == .simulated
                if self.isSimulating == false {
                    self.placeName = nil
                }
            }
        }
    }

    isolated deinit {
        self.task?.cancel()
    }

    /// Shows the app as if the device were at `location`; a simulation already running moves there.
    func start(_ location: Location, name: String?) {
        self.placeName = name
        self.isSimulating = true
        self.location.simulate(location)
    }

    /// Back to where the device really is.
    func stop() {
        self.location.endSimulation()
        self.isSimulating = false
        self.placeName = nil
    }
}
