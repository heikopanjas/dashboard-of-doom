import CoreLocation
import DoomKitLocation
import Foundation

class ProximityUsageExamples {

    func demonstrateUsage() {
        // Sample polygon (roughly a square in Germany) using your Location type
        let polygon = [
            Location(latitude: 49.8432, longitude: 8.5625),
            Location(latitude: 49.9541, longitude: 8.7244),
            Location(latitude: 49.8709, longitude: 8.7267),
            Location(latitude: 49.7962, longitude: 8.6454)
        ]

        // User's current location (outside the polygon)
        let userLocation = Location(latitude: 49.7500, longitude: 8.4000)

        // Find nearest point
        if let result = PolygonProximityCalculator.nearestPointOnPolygon(from: userLocation, to: polygon) {
            print("Nearest point: lat \(result.point.latitude), lon \(result.point.longitude)")
            print("Distance: \(Int(result.distance)) meters")
        }

        // Check if approaching
        let isApproaching = PolygonProximityCalculator.isApproachingPolygon(
            location: userLocation,
            polygon: polygon,
            threshold: 5000  // 5km
        )
        print("Is approaching warning area: \(isApproaching)")

        // Get multiple nearest points
        let nearestPoints = PolygonProximityCalculator.nearestPoints(from: userLocation, to: polygon, count: 2)
        for (index, result) in nearestPoints.enumerated() {
            print("Option \(index + 1): \(Int(result.distance))m away")
        }
    }

    // Real-world usage in a warning system
    func checkProximityToWarningArea(
        userLocation: Location,
        warningPolygon: [Location]
    ) -> String {
        guard let nearest = PolygonProximityCalculator.nearestPointOnPolygon(from: userLocation, to: warningPolygon) else {
            return "Unable to calculate distance to warning area"
        }

        let distanceKm = nearest.distance / 1000

        if distanceKm < 1 {
            return "⚠️ Very close to warning area (\(Int(nearest.distance))m)"
        }
        else if distanceKm < 5 {
            return "⚠️ Approaching warning area (\(String(format: "%.1f", distanceKm))km)"
        }
        else {
            return "Warning area is \(String(format: "%.1f", distanceKm))km away"
        }
    }

    // Complete location analysis (inside check + nearest point)
    func checkLocationStatus(userLocation: Location, warningPolygon: [Location]) -> String {
        let analysis = PolygonProximityCalculator.analyzeLocationRelativeToPolygon(
            location: userLocation,
            polygon: warningPolygon
        )
        return analysis.statusMessage
    }
}
