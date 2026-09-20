import DoomKitProcess
import SwiftUI

/// The map of the level and radiation sensors at the top of the Environment tab: a dot and a label for every sensor the tab lists.
struct EnvironmentMapView: View {
    @Environment(LevelPresenter.self) private var water
    @Environment(RadiationPresenter.self) private var radiation
    @AppStorage(SourcePreferences.multiSensorLevelKey) private var multiSensorLevel: Bool = false
    @AppStorage(SourcePreferences.multiSensorRadiationKey) private var multiSensorRadiation: Bool = false

    var body: some View {
        // The same readings the sections below list, so switching a source's Multiple Sensors off removes its extra labels at once.
        SensorMapView(
            annotations: Self.annotations(
                radiation: self.radiation.visibleReadings(multiSensor: self.multiSensorRadiation),
                water: self.water.visibleReadings(multiSensor: self.multiSensorLevel)))
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
}
