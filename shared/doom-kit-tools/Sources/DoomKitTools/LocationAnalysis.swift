import CoreLocation
import DoomKitLocation
import Foundation

public struct LocationAnalysis {
    public let isInside: Bool
    public let nearestPoint: Location?
    public let distance: Double  // in meters, 0 if inside

    public var statusMessage: String {
        if self.isInside == true {
            return "🚨 Inside warning area"
        }
        else if self.distance < 1000 {
            return "⚠️ \(Int(self.distance))m from warning area"
        }
        else {
            return "✅ \(String(format: "%.1f", self.distance/1000))km from warning area"
        }
    }
}
