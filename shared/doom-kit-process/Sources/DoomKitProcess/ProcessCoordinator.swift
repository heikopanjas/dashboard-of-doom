import DoomKitLocation
import DoomKitNetwork
import Foundation

/// Coordinates location, connectivity, and process refresh lifecycles.
@MainActor
public final class ProcessCoordinator {

    private let locationRefreshPolicy: LocationRefreshPolicy
    private let locationManager: any ProcessLocationSource
    private let networkManager: any ProcessNetworkSource
    let scheduler: ProcessManager<Location>
    private var lifecycle = UUID()
    private var locationTask: Task<Void, Never>?
    private var networkTask: Task<Void, Never>?
    private var startupTask: Task<Void, Never>?
    private var hasPerformedInitialRefresh = false
    private var startupExpired = false

    public convenience init(locationManager: LocationManager, networkManager: NetworkManager, clock: ProcessClock = .continuous, locationRefreshPolicy: LocationRefreshPolicy = .firstMeasurement) {
        self.init(locationSource: locationManager, networkSource: networkManager, clock: clock, locationRefreshPolicy: locationRefreshPolicy)
    }

    init(locationSource: any ProcessLocationSource, networkSource: any ProcessNetworkSource, clock: ProcessClock = .continuous, locationRefreshPolicy: LocationRefreshPolicy = .firstMeasurement) {
        self.locationRefreshPolicy = locationRefreshPolicy
        self.locationManager = locationSource
        self.networkManager = networkSource
        self.scheduler = ProcessManager(clock: clock)
        self.scheduler.stop()
    }

    public func start() {
        guard self.locationTask == nil else { return }
        self.startupExpired = false
        let lifecycle = UUID()
        self.lifecycle = lifecycle
        self.scheduler.resumeRefreshes()
        self.scheduler.updateContext(self.locationManager.state.location)
        self.scheduler.refreshAll()
        let updates = self.locationManager.updates()
        self.locationTask = Task { [weak self] in
            var previous: Location?
            var previousOrigin = LocationState.Origin.fallback
            for await state in updates {
                guard Task.isCancelled == false, self?.lifecycle == lifecycle else { return }
                guard state.location != previous || state.origin != previousOrigin else { continue }
                // The fallback at launch is what the first refresh already used; a return to it from a simulation is not.
                guard state.origin != .fallback || previousOrigin != .fallback else { continue }
                let simulation = state.origin == .simulated || previousOrigin == .simulated
                previous = state.location
                previousOrigin = state.origin
                self?.receive(location: state.location, origin: state.origin, simulation: simulation)
            }
        }
        self.locationManager.start()
        let network = self.networkManager
        self.networkTask = Task { [weak self] in
            await network.startMonitoring()
            guard Task.isCancelled == false else { return }
            let updates = await network.updates()
            for await state in updates {
                guard Task.isCancelled == false, let self, self.lifecycle == lifecycle else { return }
                self.scheduler.isReady = state.isConnected || self.startupExpired
            }
        }
        self.startupTask = Task { [weak self] in
            await network.startMonitoring()
            try? await network.waitForConnection(timeout: .seconds(30))
            guard Task.isCancelled == false, self?.lifecycle == lifecycle else { return }
            self?.startScheduling()
        }
    }

    private func startScheduling() {
        self.startupExpired = true
        self.scheduler.isReady = true
        self.scheduler.resetIntervals()
        self.scheduler.start()
    }

    /// A new location updates what the next refreshes use. Every source refreshes at once for the first real fix, for every fix under
    /// `.everyMovement`, and whenever a simulation starts, moves or ends, since the user is waiting to see the other place.
    private func receive(location: Location, origin: LocationState.Origin, simulation: Bool) {
        self.scheduler.updateContext(location)
        let first = origin == .measured && self.hasPerformedInitialRefresh == false
        if first == true {
            self.hasPerformedInitialRefresh = true
        }
        if first == true || simulation == true || self.locationRefreshPolicy == .everyMovement {
            self.scheduler.refreshAll()
        }
    }

    public func add(subscriber: any ProcessRefreshable, timeout: TimeInterval) {
        self.scheduler.register(id: subscriber.id, interval: .seconds(timeout * 60)) { [weak subscriber] location in
            await subscriber?.refreshData(location: location)
        }
    }

    public func remove(id: UUID) {
        self.scheduler.remove(id: id)
    }

    public func remove(subscriber: any ProcessRefreshable) {
        self.scheduler.remove(id: subscriber.id)
    }

    public func refreshSubscriptions() {
        self.scheduler.refreshAll()
    }

    /// Refreshes every subscription and returns when all of them have finished.
    public func refreshSubscriptionsAndWait() async {
        await self.scheduler.refreshAllAndWait()
    }

    public func refreshSubscription(subscriber: any ProcessRefreshable) {
        self.scheduler.refresh(id: subscriber.id)
    }

    public func stop() {
        self.lifecycle = UUID()
        self.locationTask?.cancel()
        self.networkTask?.cancel()
        self.startupTask?.cancel()
        self.locationTask = nil
        self.networkTask = nil
        self.startupTask = nil
        self.scheduler.stop()
        self.locationManager.stop()
    }

    isolated deinit {
        self.locationTask?.cancel()
        self.networkTask?.cancel()
        self.startupTask?.cancel()
        self.scheduler.shutdown()
    }
}
