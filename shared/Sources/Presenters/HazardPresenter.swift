import DoomKitLocation
import DoomKitProcess
import DoomKitTools
import Foundation
import Observation

/// Warnings near the user. Not a ProcessPresenter: there is no sensor or numeric
/// series to render. It registers with the coordinator like the other sources and
/// receives its location only through refreshData(location:).
@MainActor @Observable final class HazardPresenter: ProcessRefreshable {
    typealias Fetch = @MainActor (Location) async throws -> [Hazard]

    enum State: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    private struct Attempt {
        let location: Location
        let date: Date
    }

    static let failureCooldown: TimeInterval = 300
    static let cooldownDistance: Double = 1000

    nonisolated let id = UUID()
    private(set) var hazards: [Hazard] = []
    private(set) var timestamp: Date?
    private(set) var state: State = .loading

    @ObservationIgnored private var subscription: ConditionalSubscription?
    @ObservationIgnored private let fetch: Fetch
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var failure: Attempt?

    var isEnabled: Bool { return self.subscription?.isEnabled == true }

    init(
        defaults: UserDefaults = .standard,
        register: (@MainActor (any ProcessRefreshable, TimeInterval) -> Void)? = nil,
        remove: (@MainActor (UUID) -> Void)? = nil,
        fetch: Fetch? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.fetch = fetch ?? { location in return try await HazardController().fetchHazards(location: location) }
        self.now = now
        let id = self.id
        self.subscription = ConditionalSubscription(
            defaults: defaults, enableKey: "showHazards", intervalKey: "hazardRefreshInterval", fallback: 15,
            register: { [weak self] interval in
                guard let self else { return }
                if let register { register(self, interval) }
                else { AppProcess.shared.add(subscriber: self, timeout: interval) }
            },
            remove: {
                if let remove { remove(id) }
                else { AppProcess.shared.remove(id: id) }
            })
    }

    func refreshData(location: Location) async {
        guard self.isEnabled, Task.isCancelled == false else { return }
        if let failure = self.failure,
            self.now().timeIntervalSince(failure.date) < Self.failureCooldown,
            PointOfInterestPresenter.distance(failure.location, location) < Self.cooldownDistance
        {
            return
        }
        self.generation += 1
        let generation = self.generation
        if self.timestamp == nil { self.state = .loading }
        do {
            let hazards = try await self.fetch(location)
            try Task.checkCancellation()
            guard generation == self.generation, self.isEnabled else { return }
            self.failure = nil
            self.publish(hazards: hazards, timestamp: self.now())
            // Here rather than in publish, which the UI fixture calls.
            WarningNotifier.shared.check(hazards: hazards)
        }
        catch is CancellationError {
            return
        }
        catch {
            guard Task.isCancelled == false, generation == self.generation else { return }
            self.failure = Attempt(location: location, date: self.now())
            self.state = .failed(error.localizedDescription)
            trace.error("Error refreshing hazards: %@", error.localizedDescription)
        }
    }

    /// Also used by the Debug UI fixture.
    func publish(hazards: [Hazard], timestamp: Date) {
        if hazards != self.hazards { self.hazards = hazards }
        self.timestamp = timestamp
        self.state = .loaded
    }
}
