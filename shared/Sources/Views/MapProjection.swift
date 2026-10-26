import CoreLocation
import MapKit

/// Where a coordinate lands in a map view, worked out from the map's visible rectangle instead of asking MapKit.
///
/// The maps here cannot be rotated or pitched, so map points map linearly to view points: the visible rectangle, which the map reports
/// with every camera change, fills the view exactly. `MapProxy.convert(_:to:)` gave points about 23 points too high inside the macOS
/// dashboard popup while MapKit drew the dots in the right place, which put every label and connector above its dot; this arithmetic does
/// not depend on where the view is hosted.
enum MapProjection {
    static func point(for coordinate: CLLocationCoordinate2D, in visibleRect: MKMapRect, size: CGSize) -> CGPoint? {
        guard visibleRect.isNull == false, visibleRect.width > 0, visibleRect.height > 0, size.width > 0, size.height > 0 else { return nil }
        let mapPoint = MKMapPoint(coordinate)
        let x = (mapPoint.x - visibleRect.minX) / visibleRect.width * size.width
        let y = (mapPoint.y - visibleRect.minY) / visibleRect.height * size.height
        guard x.isFinite, y.isFinite else { return nil }
        return CGPoint(x: x, y: y)
    }

    /// The inverse: the coordinate under a point of the view, for a click on the map.
    static func coordinate(for point: CGPoint, in visibleRect: MKMapRect, size: CGSize) -> CLLocationCoordinate2D? {
        guard visibleRect.isNull == false, visibleRect.width > 0, visibleRect.height > 0, size.width > 0, size.height > 0 else { return nil }
        let mapPoint = MKMapPoint(
            x: visibleRect.minX + point.x / size.width * visibleRect.width, y: visibleRect.minY + point.y / size.height * visibleRect.height)
        let coordinate = mapPoint.coordinate
        guard CLLocationCoordinate2DIsValid(coordinate) else { return nil }
        return coordinate
    }
}
