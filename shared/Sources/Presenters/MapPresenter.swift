import DoomKitProcess
import DoomKitLocation
import Foundation
import MapKit
import SwiftUI

@Observable class MapPresenter {
    /// The nearest sensor of each source that takes part in the camera, with the check that says whether it does right now.
    private struct Entry {
        var location: Location
        var isVisible: @MainActor () -> Bool
    }

    /// The locations the camera fits, by presenter: the entries whose check passes. Recomputed from `entries`, never edited directly.
    private(set) var visibleRegion: [UUID: Location] = [:]
    var visibleRectangle = MKMapRect.null
    var region = MapCameraPosition.region(MKCoordinateRegion(MKMapRect.null))

    @ObservationIgnored private var entries: [UUID: Entry] = [:]
    @ObservationIgnored private var observer: NSObjectProtocol?

    public static let shared = MapPresenter()

    /// A switch can change while the home map is not on screen, in Settings or with the window closed, so the presenter itself watches the
    /// settings rather than the view: switching a source off takes its sensor out of the camera at once, wherever the change was made.
    private init() {
        self.observer = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) {
            [weak self] _ in
            MainActor.assumeIsolated { self?.refreshRegion() }
        }
    }

#if os(macOS)
    static let frameOffset = 0.0
#else
    static let frameOffset = 10_000.0
#endif

    /// Records where a source's nearest sensor is, and when it counts. Without a check an existing entry keeps its own, which is how the
    /// iOS map moves the weather marker with the reader, and a new one always counts.
    @MainActor func updateRegion(for id: UUID, with location: Location, isVisible: (@MainActor () -> Bool)? = nil) -> Void {
        let check = isVisible ?? self.entries[id]?.isVisible ?? { true }
        self.entries[id] = Entry(location: location, isVisible: check)
        self.refreshRegion()
    }

    @MainActor func updateRegion(remove id: UUID) -> Void {
        guard self.entries.removeValue(forKey: id) != nil else { return }
        self.refreshRegion()
    }

    /// Rebuilds the rectangle from scratch from the entries that count now, so it shrinks as well as grows: a sensor that moved or a
    /// source switched off leaves nothing behind. The camera only moves when the set of visible locations changed, since unrelated
    /// settings are written all the time.
    @MainActor func refreshRegion() -> Void {
        let visible = self.entries.filter { $0.value.isVisible() }.mapValues { $0.location }
        guard visible != self.visibleRegion else { return }
        self.visibleRegion = visible
        let rectangle = Self.rectangle(for: Array(visible.values))
        self.visibleRectangle = rectangle
        self.region = MapCameraPosition.region(MKCoordinateRegion(rectangle))
    }

    /// The camera rectangle for these locations alone: a box around each, as wide as half the greatest distance between any two, joined.
    /// Null for none.
    static func rectangle(for locations: [Location]) -> MKMapRect {
        var rectangle = MKMapRect.null
        let maxDistance = Self.greatestDistance(locations: locations)
        for location in locations {
            let boundingRectangle = Self.makeBoundingRectangle(
                centerCoordinate: location.coordinate, widthMeters: (maxDistance.value / 2) + Self.frameOffset,
                heightMeters: (maxDistance.value / 2) + Self.frameOffset)
            rectangle = rectangle.union(boundingRectangle)
        }
        return rectangle
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
