import DoomKitLocation
import MapKit
import SwiftUI

/// The map at the top of a tab that lists several sensors: a dot and a label for each annotation, on a camera fitted to them, and a divider
/// below it.
///
/// It is not the home map. That one labels the nearest sensor of every source and owns the shared camera in `MapPresenter`, which this
/// must not disturb, so this one has its own camera and nothing but the sensors and the reader's own position: no points of interest and no
/// weather label. Like the home map it cannot be panned, so it does not fight the scrolling of the tab.
struct SensorMapView: View {
    let annotations: [MapAnnotationSnapshot]
    /// Areas to shade under the dots, such as the COVID district, which the camera also fits.
    var polygons: [[Location]] = []
    /// How much room to leave around what the map shows, as a factor on the bounding box. The default doubles it, which is the room six
    /// labels need; a map showing one district needs far less, or the shape would sit in the middle of an empty frame.
    var padding: Double = 2

    /// Where the reader is, so the distance under each chart has something to point at. The home map shows this as its weather annotation
    /// flagged `user`; here it is a marker of its own, because these tabs have no weather label to hang it on.
    @State private var userLocation = AppLocation.shared.state.location

    /// The height the home map has on iOS, without its header row. macOS keeps the phone height, fixed like its charts, so the window size
    /// never changes it.
    private static var height: CGFloat {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad ? 667 : 367
        #else
        return 367
        #endif
    }

    /// The smallest area the camera shows, so a lone sensor, or two close neighbours, do not zoom in to nothing.
    private static let minimumSpan: Double = 3_000

    var body: some View {
        // Nothing until a sensor has loaded, so the spinners below are the only sign of loading and the map appears with the data. The gate
        // is the sensors alone: the user marker must never be enough to make an empty map appear.
        if self.annotations.isEmpty == false,
            let rect = Self.rect(
                for: self.polygons.flatMap { $0 } + self.annotations.map { $0.location } + [self.userLocation], padding: self.padding)
        {
            VStack {
                CollisionMapView(
                    position: Binding(get: { MapCameraPosition.rect(rect) }, set: { _ in }),
                    annotations: self.annotations + [Self.userAnnotation(at: self.userLocation)],
                    polygons: self.polygons
                )
                .frame(height: Self.height)
                .padding(5)
                .padding(.trailing, 5)
                Divider()
                    .padding(.horizontal, 5)
                    .padding(.trailing, 5)
            }
            .task {
                // Observes only; never starts tracking. Same footprint as MapView.
                for await state in AppLocation.shared.updates() {
                    guard Task.isCancelled == false else { return }
                    self.userLocation = state.location
                }
            }
        }
    }

    /// The reader's own marker: a black dot with the white halo the home map gives the user, and no label, since a coordinate has no reading
    /// to show. The selector is inert here, because `displayColor` takes the explicit color and a marker without a label draws neither a
    /// label nor a connector; it is the weather selector because that is the one the home map's user marker carries.
    static func userAnnotation(at location: Location) -> MapAnnotationSnapshot {
        return MapAnnotationSnapshot(
            id: "user", location: location, selector: .weather(.temperature), icon: "location.fill", faceplate: "", user: true,
            showsLabel: false, color: .user)
    }

    /// The camera rectangle for the points it is given, the sensors, any district outline and the reader: their bounding box scaled by
    /// `padding` about its centre, to leave room for the labels, and not smaller than `minimumSpan`. Nil when there are no points.
    ///
    /// The reader's position is one of them, so the marker is always on screen. A far sensor therefore zooms the camera out until both fit,
    /// which is the right answer: when the nearest gauge on a natural waterway is a hundred kilometres away, that distance is the reading.
    static func rect(for locations: [Location], padding: Double = 2) -> MKMapRect? {
        if locations.isEmpty == true {
            return nil
        }
        var box = MKMapRect.null
        for location in locations {
            box = box.union(MKMapRect(origin: MKMapPoint(location.coordinate), size: MKMapSize(width: 0, height: 0)))
        }
        let center = MKMapPoint(x: box.midX, y: box.midY)
        let minimum = Self.minimumSpan * MKMapPointsPerMeterAtLatitude(center.coordinate.latitude)
        let width = max(box.size.width * padding, minimum)
        let height = max(box.size.height * padding, minimum)
        return MKMapRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height)
    }
}
