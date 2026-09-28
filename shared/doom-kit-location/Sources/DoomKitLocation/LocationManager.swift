import Foundation

@MainActor
public final class LocationManager {
    public private(set) var state: LocationState
    private let provider: any LocationProvider
    private var observers: [UUID: AsyncStream<LocationState>.Continuation] = [:]
    private var generation = UUID()
    private let fallback: Location
    /// The last real fix, kept apart from `state` so a simulation can end where the device really is, without waiting for a new fix.
    private var lastMeasured: Location?
    private var simulated: Location?

    /// Whether the app shows a place the user chose rather than where the device is.
    public var isSimulating: Bool {
        return self.simulated != nil
    }

    public convenience init(fallback: Location, configuration: LocationConfiguration = .foreground) {
        self.init(fallback: fallback, provider: CoreLocationProvider(configuration: configuration))
    }

    init(fallback: Location, provider: any LocationProvider) {
        self.state = LocationState(
            location: fallback, origin: .fallback,
            authorization: .notDetermined, tracking: .stopped)
        self.provider = provider
        self.fallback = fallback
    }

    /// Shows the app as if the device were at `location`, until `endSimulation()`. Real fixes keep arriving and are remembered, but no
    /// longer move the location; the streams stay open, so every observer follows.
    public func simulate(_ location: Location) {
        self.simulated = location
        self.state.location = location
        self.state.origin = .simulated
        self.broadcast()
    }

    /// Back to where the device really is: the last fix, or the fallback when there has been none.
    public func endSimulation() {
        guard self.simulated != nil else { return }
        self.restoreRealLocation()
        self.broadcast()
    }

    private func restoreRealLocation() {
        self.simulated = nil
        if let lastMeasured = self.lastMeasured {
            self.state.location = lastMeasured
            self.state.origin = .measured
        }
        else {
            self.state.location = self.fallback
            self.state.origin = .fallback
        }
    }

    public func updates() -> AsyncStream<LocationState> {
        let id = UUID()
        let (stream, continuation) = AsyncStream.makeStream(of: LocationState.self, bufferingPolicy: .bufferingNewest(1))
        self.observers[id] = continuation
        continuation.yield(self.state)
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor [weak self] in self?.observers.removeValue(forKey: id) }
        }
        return stream
    }

    public func start() {
        guard self.state.tracking == .stopped else { return }
        let generation = UUID()
        self.generation = generation
        self.provider.onUpdate = { [weak self] update in
            guard let self, self.generation == generation, self.state.tracking != .stopped else { return }
            self.receive(update)
        }
        self.state.tracking = .starting
        self.broadcast()
        self.provider.start()
    }

    /// Stops tracking and ends a simulation with it, so a simulation never outlives the app.
    public func stop() {
        if self.simulated != nil { self.restoreRealLocation() }
        self.generation = UUID()
        self.provider.onUpdate = nil
        self.provider.stop()
        self.state.tracking = .stopped
        self.broadcast()
        for continuation in self.observers.values { continuation.finish() }
        self.observers.removeAll()
    }

    private func receive(_ update: LocationProviderUpdate) {
        self.state.authorization = update.authorization
        self.state.authorizationScope = update.authorizationScope
        self.state.failure = update.failure
        if update.authorization == .denied || update.authorization == .restricted {
            self.state.failure = .denied
        }
        if let location = update.location {
            let previous = self.lastMeasured ?? self.state.location
            if self.lastMeasured == nil || haversineDistance(location_0: previous, location_1: location).value > 100 {
                self.lastMeasured = location
                // While simulating, the fix is only remembered for when the simulation ends.
                if self.simulated == nil {
                    self.state.location = location
                    self.state.origin = .measured
                }
            }
            self.state.tracking = .tracking
        }
        self.broadcast()
    }

    private func broadcast() {
        for continuation in self.observers.values { continuation.yield(self.state) }
    }

    isolated deinit {
        self.provider.onUpdate = nil
        self.provider.stop()
        for continuation in self.observers.values { continuation.finish() }
    }
}
