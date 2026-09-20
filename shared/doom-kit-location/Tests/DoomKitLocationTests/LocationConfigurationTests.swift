import CoreLocation
import Testing
@testable import DoomKitLocation

@MainActor
struct LocationConfigurationTests {
    private final class Settings: LocationConfigurable {
        var desiredAccuracy: CLLocationAccuracy = 0
        #if os(iOS)
        var allowsBackgroundLocationUpdates = false
        var pausesLocationUpdatesAutomatically = true
        var showsBackgroundLocationIndicator = false
        #endif
    }

    @Test func foregroundAccuracyIsUnchanged() {
        let manager = Settings()
        LocationConfiguration.foreground.apply(to: manager)
        #expect(manager.desiredAccuracy == kCLLocationAccuracyKilometer)
    }

    #if os(iOS)
    @Test func continuousBackgroundConfiguration() {
        let manager = Settings()
        LocationConfiguration.continuousBackground.apply(to: manager)
        #expect(manager.desiredAccuracy == kCLLocationAccuracyBest)
        #expect(manager.allowsBackgroundLocationUpdates == true)
        #expect(manager.pausesLocationUpdatesAutomatically == false)
        #expect(manager.showsBackgroundLocationIndicator == true)
    }
    #endif
}
