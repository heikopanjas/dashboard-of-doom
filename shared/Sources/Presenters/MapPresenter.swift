import DoomKitProcess
import DoomKitLocation
import Foundation
import MapKit
import SwiftUI

@Observable class MapPresenter {
    var visibleRegion: [UUID: Location] = [:]
    var visibleRectangle = MKMapRect.null
    var region = MapCameraPosition.region(MKCoordinateRegion(MKMapRect.null))

    public static let shared = MapPresenter()
    private init() {}

#if os(macOS)
    static let frameOffset = 0.0
#else
    static let frameOffset = 10_000.0
#endif

    @MainActor func resetRegion() -> Void {
        self.visibleRectangle = MKMapRect.null
        self.region = MapCameraPosition.region(MKCoordinateRegion(self.visibleRectangle))
    }

    @MainActor func updateRegion(for id: UUID, with location: Location) -> Void {
        self.visibleRegion[id] = location
        self.refreshRegion()
    }

    @MainActor func updateRegion(remove id: UUID) -> Void {
        if self.visibleRegion[id] != nil {
            self.visibleRegion.removeValue(forKey: id)
            self.resetRegion()
            self.refreshRegion()
        }
    }

    @MainActor private func refreshRegion() -> Void {
        if self.visibleRegion.isEmpty == false {
        let maxDistance = Self.greatestDistance(locations: Array(self.visibleRegion.values))
        for location in self.visibleRegion.values {
            let boundingRectangle = Self.makeBoundingRectangle(
                centerCoordinate: location.coordinate, widthMeters: (maxDistance.value / 2) + Self.frameOffset, heightMeters: (maxDistance.value / 2) + Self.frameOffset)
            self.visibleRectangle = self.visibleRectangle.union(boundingRectangle)
        }
        }
        self.region = MapCameraPosition.region(MKCoordinateRegion(self.visibleRectangle))
    }

    private static func greatestDistance(locations: [Location]) -> Measurement<UnitLength> {
        var maxDistance = Measurement<UnitLength>(value: 0.0, unit: .meters)
        for i in 0 ..< locations.count {
            for j in i + 1 ..< locations.count {
                let distance = haversineDistance(location_0: locations[i], location_1: locations[j])
                if distance > maxDistance {
                    maxDistance = distance
                }
            }
        }
        return maxDistance
    }

    private static func makeBoundingRectangle(centerCoordinate: CLLocationCoordinate2D, widthMeters: Double, heightMeters: Double) -> MKMapRect {
        // Convert center coordinate to map point
        let centerPoint = MKMapPoint(centerCoordinate)

        // Calculate points per meter at this latitude
        let metersPerPoint = MKMetersPerMapPointAtLatitude(centerCoordinate.latitude)

        let actualWidthMeters = (widthMeters < 1000.0) ? 1000.0 : widthMeters
        let actualHeightMeters = (heightMeters < 1000.0) ? 1000.0 : heightMeters

        // Convert meters to points
        let widthPoints = actualWidthMeters / metersPerPoint
        let heightPoints = actualHeightMeters / metersPerPoint

        // Create rect centered on the point
        return MKMapRect(
            x: centerPoint.x - widthPoints / 2,
            y: centerPoint.y - heightPoints / 2,
            width: widthPoints,
            height: heightPoints
        )
    }

}

extension MapPresenter {
    // Creates a binding for any property
    func binding<Value>(for keyPath: ReferenceWritableKeyPath<MapPresenter, Value>) -> Binding<Value> {
        Binding(
            get: { self[keyPath: keyPath] },
            set: { self[keyPath: keyPath] = $0 }
        )
    }
}
