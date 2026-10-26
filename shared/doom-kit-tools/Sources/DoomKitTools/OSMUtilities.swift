import DoomKitLocation
import Foundation

public func calculateBoundingBox(
    center: Location, radiusInMeters: Double
) -> (minLatitude: Double, minLongitude: Double, maxLatitude: Double, maxLongitude: Double) {
    // Convert radius from meters to degrees (approximate)
    // 1 degree of latitude is approximately 111,320 meters
    let radiusLat = radiusInMeters / 111320.0

    // 1 degree of longitude varies with latitude (narrower at higher latitudes)
    // cos(latitude in radians) gives the ratio of longitude degree to latitude degree
    let radiusLon = radiusInMeters / (111320.0 * cos(center.latitude * .pi / 180.0))

    // Calculate the bounds
    let minLatitude = center.latitude - radiusLat
    let maxLatitude = center.latitude + radiusLat
    let minLongitude = center.longitude - radiusLon
    let maxLongitude = center.longitude + radiusLon

    return (minLatitude, minLongitude, maxLatitude, maxLongitude)
}
