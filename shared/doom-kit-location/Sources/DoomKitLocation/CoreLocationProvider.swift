import CoreLocation

@MainActor
final class CoreLocationProvider: LocationProvider {
    private let configuration: LocationConfiguration

    init(configuration: LocationConfiguration = .foreground) {
        self.configuration = configuration
    }

    private var manager: CLLocationManager?
    private var delegate: Delegate?
    var onUpdate: (@MainActor (LocationProviderUpdate) -> Void)?

    func start() {
        guard self.manager == nil else { return }
        let manager = CLLocationManager()
        let delegate = Delegate()
        // Capture this lifecycle's handler, so queued callbacks cannot adopt a new one.
        delegate.receive = self.onUpdate
        manager.delegate = delegate
        self.manager = manager
        self.delegate = delegate
        self.configuration.apply(to: manager)
        #if os(iOS)
        if self.configuration == .continuousBackground {
            manager.requestAlwaysAuthorization()
        }
        else {
            manager.requestWhenInUseAuthorization()
        }
        #else
        manager.requestWhenInUseAuthorization()
        #endif
        manager.startUpdatingLocation()
    }

    func stop() {
        self.manager?.stopUpdatingLocation()
        self.manager?.delegate = nil
        self.delegate?.receive = nil
        self.manager = nil
        self.delegate = nil
    }

    @MainActor private final class Delegate: NSObject, @preconcurrency CLLocationManagerDelegate {
        var receive: (@MainActor (LocationProviderUpdate) -> Void)?

        private func authorization(_ manager: CLLocationManager) -> LocationState.Authorization {
            switch manager.authorizationStatus {
                case .authorizedAlways, .authorizedWhenInUse: return .authorized
                case .denied: return .denied
                case .restricted: return .restricted
                default: return .notDetermined
            }
        }

        private func scope(_ manager: CLLocationManager) -> LocationState.AuthorizationScope {
            switch manager.authorizationStatus {
                case .authorizedAlways: return .always
                case .authorizedWhenInUse: return .whenInUse
                default: return .unknown
            }
        }

        func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
            self.receive?(.init(authorization: self.authorization(manager), authorizationScope: self.scope(manager)))
        }

        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            guard let location = locations.last else { return }
            self.receive?(
                .init(
                    location: Location(
                        latitude: location.coordinate.latitude,
                        longitude: location.coordinate.longitude),
                    authorization: self.authorization(manager), authorizationScope: self.scope(manager)))
        }

        func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
            let code = (error as NSError).code
            let failure: LocationState.Failure =
                code == CLError.denied.rawValue ? .denied : (code == CLError.locationUnknown.rawValue ? .unavailable : .other(code))
            self.receive?(.init(authorization: self.authorization(manager), failure: failure, authorizationScope: self.scope(manager)))
        }
    }
}
