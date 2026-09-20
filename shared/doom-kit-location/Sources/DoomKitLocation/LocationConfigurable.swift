import CoreLocation

/// The settings boundary permits policy tests without native authorization or tracking.
@MainActor
protocol LocationConfigurable: AnyObject {
    var desiredAccuracy: CLLocationAccuracy { get set }
    #if os(iOS)
    var allowsBackgroundLocationUpdates: Bool { get set }
    var pausesLocationUpdatesAutomatically: Bool { get set }
    var showsBackgroundLocationIndicator: Bool { get set }
    #endif
}

extension CLLocationManager: LocationConfigurable {}
