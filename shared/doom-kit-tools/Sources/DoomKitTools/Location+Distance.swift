import CoreLocation
import DoomKitLocation
import Foundation

extension Location {
    /// Calculate distance in meters between two locations using Haversine formula
    public func distance(to location: Location) -> Double {
        let location1 = CLLocation(latitude: self.latitude, longitude: self.longitude)
        let location2 = CLLocation(latitude: location.latitude, longitude: location.longitude)
        return location1.distance(from: location2)
    }

    /// Calculate squared distance (faster for comparisons, no need for sqrt)
    public func squaredDistance(to location: Location) -> Double {
        let deltaLat = self.latitude - location.latitude
        let deltaLon = self.longitude - location.longitude
        return deltaLat * deltaLat + deltaLon * deltaLon
    }

    /// Convert to CLLocationCoordinate2D for compatibility
    public var clLocationCoordinate2D: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: self.latitude, longitude: self.longitude)
    }
}
