import DoomKitLocation
import DoomKitProcess
import MapKit
import SwiftUI

/// A map of the level and radiation sensors for the top of the Environment tab: a dot and a label for every sensor the tab lists.
///
/// It is not the home map. That one labels the nearest sensor of every source and owns the shared camera in `MapPresenter`, which this
/// must not disturb, so this one has its own camera, fitted to the sensors it shows, and nothing but the sensors: no points of interest,
/// weather label or user marker. Like the home map it cannot be panned, so it does not fight the scrolling of the tab.
struct EnvironmentMapView: View {
    @Environment(LevelPresenter.self) private var water
    @Environment(RadiationPresenter.self) private var radiation
    @AppStorage(SourcePreferences.multiSensorLevelKey) private var multiSensorLevel: Bool = false
    @AppStorage(SourcePreferences.multiSensorRadiationKey) private var multiSensorRadiation: Bool = false

    /// The height the home map has, without its header row.
    private static var height: CGFloat {
        return UIDevice.current.userInterfaceIdiom == .pad ? 667 : 367
    }

    /// The smallest area the camera shows, so a lone sensor, or two close neighbours, do not zoom in to nothing.
    private static let minimumSpan: Double = 3_000

    var body: some View {
        // The same readings the sections below list, so switching a source's Multiple Sensors off removes its extra labels at once.
        let annotations = Self.annotations(
            radiation: self.radiation.visibleReadings(multiSensor: self.multiSensorRadiation),
            water: self.water.visibleReadings(multiSensor: self.multiSensorLevel))
        // Nothing until a sensor has loaded, so the spinners below are the only sign of loading and the map appears with the data.
        if let rect = Self.rect(for: annotations.map { $0.location }) {
            VStack {
                CollisionMapView(position: Binding(get: { MapCameraPosition.rect(rect) }, set: { _ in }), annotations: annotations)
                    .frame(height: Self.height)
                    .padding(5)
                    .padding(.trailing, 5)
                Divider()
                    .padding(.horizontal, 5)
                    .padding(.trailing, 5)
            }
        }
    }

    /// One annotation per reading, radiation before level as on the tab, which is also the order the label solver gives priority.
    static func annotations(radiation: [ProcessReading], water: [ProcessReading]) -> [MapAnnotationSnapshot] {
        return Self.snapshots(of: radiation, category: "radiation", selector: .radiation(.total))
            + Self.snapshots(of: water, category: "water", selector: .water(.level))
    }

    /// Ids come from the reading, which is the source's own id, so a sensor keeps its label placement across refreshes; the category keeps a
    /// level gauge and a radiation station apart, and an id used twice would silently drop a label.
    private static func snapshots(of readings: [ProcessReading], category: String, selector: ProcessSelector) -> [MapAnnotationSnapshot] {
        // The position in the list picks the color, the same one the section for that sensor below the map uses for its header.
        return readings.enumerated().map { index, reading in
            return MapAnnotationSnapshot(
                id: "\(category)-\(reading.id)", location: reading.sensor.location, selector: selector,
                icon: (reading.sensor.customData?["icon"] as? String) ?? "questionmark.circle", faceplate: reading.faceplate[selector] ?? "n/a",
                color: Color.sensor(selector: selector, index: index))
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
