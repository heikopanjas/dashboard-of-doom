import DoomKitLocation
import MapKit
import SwiftUI

/// The map at the top of a tab that lists several sensors: a dot and a label for each annotation, on a camera fitted to them, and a divider
/// below it.
///
/// It is not the home map. That one labels the nearest sensor of every source and owns the shared camera in `MapPresenter`, which this
/// must not disturb, so this one has its own camera and nothing but the sensors: no points of interest, weather label or user marker. Like
/// the home map it cannot be panned, so it does not fight the scrolling of the tab.
struct SensorMapView: View {
    let annotations: [MapAnnotationSnapshot]

    /// The height the home map has, without its header row.
    private static var height: CGFloat {
        return UIDevice.current.userInterfaceIdiom == .pad ? 667 : 367
    }

    /// The smallest area the camera shows, so a lone sensor, or two close neighbours, do not zoom in to nothing.
    private static let minimumSpan: Double = 3_000

    var body: some View {
        // Nothing until a sensor has loaded, so the spinners below are the only sign of loading and the map appears with the data.
        if let rect = Self.rect(for: self.annotations.map { $0.location }) {
            VStack {
                CollisionMapView(position: Binding(get: { MapCameraPosition.rect(rect) }, set: { _ in }), annotations: self.annotations)
                    .frame(height: Self.height)
                    .padding(5)
                    .padding(.trailing, 5)
                Divider()
                    .padding(.horizontal, 5)
                    .padding(.trailing, 5)
            }
        }
    }

    /// The camera rectangle for the sensors: their bounding box grown by half its size on every side, to leave room for the labels, and not
    /// smaller than `minimumSpan`. Nil when there are no sensors.
    static func rect(for locations: [Location]) -> MKMapRect? {
        if locations.isEmpty == true {
            return nil
        }
        var box = MKMapRect.null
        for location in locations {
            box = box.union(MKMapRect(origin: MKMapPoint(location.coordinate), size: MKMapSize(width: 0, height: 0)))
        }
        let center = MKMapPoint(x: box.midX, y: box.midY)
        let minimum = Self.minimumSpan * MKMapPointsPerMeterAtLatitude(center.coordinate.latitude)
        let width = max(box.size.width * 2, minimum)
        let height = max(box.size.height * 2, minimum)
        return MKMapRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height)
    }
}
