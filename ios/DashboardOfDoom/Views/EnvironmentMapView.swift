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
        return SensorAnnotations.radiation(radiation) + SensorAnnotations.water(water)
    }
}
