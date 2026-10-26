import CoreLocation
import DoomKitLocation
import Foundation

public class FastPolygonProximity {
    public init() {}

    private var lastPolygon: [Location] = []
    private var precomputedEdges: [(start: Location, end: Location)] = []

    /// Precompute polygon edges for faster repeated calculations
    public func setPolygon(_ polygon: [Location]) {
        self.lastPolygon = polygon
        self.precomputedEdges = []

        for i in 0 ..< polygon.count {
            let start = polygon[i]
            let end = polygon[(i + 1) % polygon.count]
            self.precomputedEdges.append((start: start, end: end))
        }
    }

    /// Fast calculation using precomputed edges
    public func nearestPoint(from location: Location) -> (point: Location, distance: Double)? {
        guard self.precomputedEdges.isEmpty == false else { return nil }

        var nearestPoint = self.precomputedEdges[0].start
        var minDistance = Double.greatestFiniteMagnitude

        for edge in self.precomputedEdges {
            let closestPointOnEdge = PolygonProximityCalculator.nearestPointOnLineSegment(
                point: location,
                lineStart: edge.start,
                lineEnd: edge.end
            )

            let distance = location.distance(to: closestPointOnEdge)

            if distance < minDistance {
                minDistance = distance
                nearestPoint = closestPointOnEdge
            }
        }

        return (point: nearestPoint, distance: minDistance)
    }
}
