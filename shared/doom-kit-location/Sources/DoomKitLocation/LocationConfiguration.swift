import CoreLocation

/// Platform-selected tracking policy. Construction never starts tracking.
public enum LocationConfiguration: Sendable, Equatable {
    case foreground
    #if os(iOS)
    case continuousBackground
    #endif

    @MainActor
    func apply(to manager: any LocationConfigurable) {
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        #if os(iOS)
        if self == .continuousBackground {
            manager.desiredAccuracy = kCLLocationAccuracyBest
            manager.allowsBackgroundLocationUpdates = true
            manager.pausesLocationUpdatesAutomatically = false
            manager.showsBackgroundLocationIndicator = true
        }
        #endif
    }
}
