import DoomKitLocation

@MainActor
protocol ProcessLocationSource: AnyObject {
    var state: LocationState { get }
    func updates() -> AsyncStream<LocationState>
    func start()
    func stop()
}

extension LocationManager: ProcessLocationSource {}
