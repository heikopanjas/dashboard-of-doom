import Foundation

@MainActor
public final class LocationManager {
    public private(set) var state: LocationState
    private let provider: any LocationProvider
    private var observers: [UUID: AsyncStream<LocationState>.Continuation] = [:]
    private var generation = UUID()

    public convenience init(fallback: Location, configuration: LocationConfiguration = .foreground) {
        self.init(fallback: fallback, provider: CoreLocationProvider(configuration: configuration))
    }

    init(fallback: Location, provider: any LocationProvider) {
        self.state = LocationState(
            location: fallback, origin: .fallback,
            authorization: .notDetermined, tracking: .stopped)
        self.provider = provider
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

    public func stop() {
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
            if self.state.origin == .fallback || haversineDistance(location_0: self.state.location, location_1: location).value > 100 {
                self.state.location = location
                self.state.origin = .measured
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
