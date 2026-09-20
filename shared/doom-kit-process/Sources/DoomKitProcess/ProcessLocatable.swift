import DoomKitLocation
import Foundation

public protocol ProcessLocatable {
    var location: Location { get }
}

public func sortByDistance<T: ProcessLocatable>(_ items: [T], from location: Location, limit: Int = 0) -> [T] {
    let sortedItems = items.sorted {
        haversineDistance(location_0: location, location_1: $0.location) < haversineDistance(location_0: location, location_1: $1.location)
    }
    if limit > 0 {
        return Array(sortedItems.prefix(limit))
    }
    else {
        return sortedItems
    }
}

public func maxDistance<T: ProcessLocatable>(_ items: [T], from location: Location, limit: Int = 0) -> Measurement<UnitLength> {
    let sorted = sortByDistance(items, from: location, limit: limit)

    guard let farthest = sorted.last else { return Measurement(value: 0.0, unit: UnitLength.meters) }
    return haversineDistance(location_0: location, location_1: farthest.location)
}

public func minDistance<T: ProcessLocatable>(_ items: [T], from location: Location, limit: Int = 0) -> Measurement<UnitLength> {
    let sorted = sortByDistance(items, from: location, limit: limit)

    guard let nearest = sorted.first else { return Measurement(value: 0.0, unit: UnitLength.meters) }
    return haversineDistance(location_0: location, location_1: nearest.location)
}

/// Ray casting algorithm to determine if a point lies within a polygon
/// - Parameters:
///   - point: The point to test (Location)
///   - polygon: Array of Location representing the polygon vertices
/// - Returns: Bool indicating whether the point is inside the polygon
public func isPointInPolygon(point: Location, polygon: [Location]) -> Bool {
    guard polygon.count >= 3 else { return false }

    let x = point.longitude
    let y = point.latitude
    var inside = false

    var j = polygon.count - 1
    for i in 0 ..< polygon.count {
        let xi = polygon[i].longitude
        let yi = polygon[i].latitude
        let xj = polygon[j].longitude
        let yj = polygon[j].latitude

        if ((yi > y) != (yj > y)) && (x < (xj - xi) * (y - yi) / (yj - yi) + xi) {
            inside.toggle()
        }
        j = i
    }
    return inside
}

/// Ray casting algorithm to determine if an item lies within a polygon
/// - Parameters:
///   - item: The item to test (must conform to Locatable)
///   - polygon: Array of Location representing the polygon vertices
/// - Returns: Bool indicating whether the item is inside the polygon
public func isItemInPolygon<T: ProcessLocatable>(_ item: T, polygon: [Location]) -> Bool {
    return isPointInPolygon(point: item.location, polygon: polygon)
}

/// Filters an array of items to only those within a polygon
/// - Parameters:
///   - items: Array of items conforming to Locatable
///   - polygon: Array of Location representing the polygon vertices
/// - Returns: Array of items that are inside the polygon
public func filterItemsInPolygon<T: ProcessLocatable>(_ items: [T], polygon: [Location]) -> [T] {
    guard polygon.count >= 3 else { return [] }

    return items.filter { item in
        isPointInPolygon(point: item.location, polygon: polygon)
    }
}
