import DoomKitLocation
import Foundation

/// Outer rings of GeoJSON geometries, as latitude/longitude locations.
enum GeoJSON {
    /// The outer ring of a Polygon, or one ring per part of a MultiPolygon.
    /// Any other geometry type yields an empty list.
    static func polygons(from geometry: [String: Any]) -> [[Location]] {
        guard let type = geometry["type"] as? String else { return [] }
        switch type {
            case "Polygon":
                guard let rings = geometry["coordinates"] as? [[[Double]]], let outer = rings.first else { return [] }
                return [Self.ring(from: outer)]
            case "MultiPolygon":
                guard let parts = geometry["coordinates"] as? [[[[Double]]]] else { return [] }
                return parts.compactMap { $0.first }.map { Self.ring(from: $0) }
            default:
                return []
        }
    }

    /// Every feature's outer rings, in feature order. NINA regions carry one
    /// feature per district, so reading only the first would miss most of them.
    static func polygons(fromFeatureCollection json: [String: Any]) -> [[Location]] {
        guard let features = json["features"] as? [[String: Any]] else { return [] }
        return features.flatMap { feature -> [[Location]] in
            guard let geometry = feature["geometry"] as? [String: Any] else { return [] }
            return Self.polygons(from: geometry)
        }
    }

    private static func ring(from coordinates: [[Double]]) -> [Location] {
        return coordinates.compactMap { point in
            guard point.count >= 2 else { return nil }
            return Location(latitude: point[1], longitude: point[0])
        }
    }
}
