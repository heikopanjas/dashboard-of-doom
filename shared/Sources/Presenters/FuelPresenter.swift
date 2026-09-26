import DoomKitLocation
import DoomKitProcess
import DoomKitTools
import Foundation
import Observation

/// Filling stations near the user. Not a ProcessPresenter: there is no sensor or numeric series to render, only a list of places and
/// their prices. It receives its location the same way the hazards do, through refreshData(location:).
@MainActor @Observable final class FuelPresenter: ProcessRefreshable {
    typealias Fetch = @MainActor (Location) async throws -> [FuelStation]

    private struct Attempt {
        let location: Location
        let date: Date
    }

    /// Tankerkoenig asks for no more than one request every five minutes, and iOS refreshes on every movement, so a failure is not retried
    /// until the user has moved on or the cooldown has passed.
    static let failureCooldown: TimeInterval = 300
    static let cooldownDistance: Double = 1000

    nonisolated let id = UUID()
    private(set) var stations: [FuelStation] = []
    private(set) var timestamp: Date?

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
        self.fetch = fetch ?? { location in return try await FuelController().fetchStations(location: location) }
        self.now = now
        let id = self.id
        // The Energy switch governs the whole tab, prices and stations alike; the prices keep their own six-hour interval.
        self.subscription = ConditionalSubscription(
            defaults: defaults, enableKey: SourcePreferences.energyEnableKey, intervalKey: "fuelRefreshInterval", fallback: 60,
            defaultEnabled: SourcePreferences.energyEnabledByDefault,
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
        do {
            let stations = try await self.fetch(location)
            try Task.checkCancellation()
            guard generation == self.generation, self.isEnabled else { return }
            self.failure = nil
            self.publish(stations: stations, timestamp: self.now())
            // Here rather than in publish, which the UI fixture calls.
            WarningNotifier.shared.check(stations: stations)
        }
        catch is CancellationError {
            return
        }
        catch {
            guard Task.isCancelled == false, generation == self.generation else { return }
            self.failure = Attempt(location: location, date: self.now())
            trace.error("Error refreshing fuel stations: %@", error.localizedDescription)
        }
    }

    /// Also used by the Debug UI fixture.
    func publish(stations: [FuelStation], timestamp: Date) {
        if stations != self.stations { self.stations = stations }
        self.timestamp = timestamp
    }
}
