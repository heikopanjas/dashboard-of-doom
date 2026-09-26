import DoomKitProcess
import SwiftUI

/// The map of the level and radiation sensors at the top of the Environment tab: a dot and a label for every sensor the tab lists.
struct EnvironmentMapView: View {
    @Environment(LevelPresenter.self) private var water
    @Environment(RadiationPresenter.self) private var radiation
    @AppStorage(SourcePreferences.multiSensorLevelKey) private var multiSensorLevel: Bool = false
    @AppStorage(SourcePreferences.multiSensorRadiationKey) private var multiSensorRadiation: Bool = false
    @AppStorage(SourcePreferences.waterKey) private var showWater: Bool = true
    @AppStorage(SourcePreferences.radiationKey) private var showRadiation: Bool = true

    var body: some View {
        // The same readings the sections below list, so switching a source's Multiple Sensors off removes its extra labels at once, and
        // switching the source off removes all of them.
        SensorMapView(
            annotations: Self.annotations(
                radiation: self.showRadiation == true ? self.radiation.visibleReadings(multiSensor: self.multiSensorRadiation) : [],
                water: self.showWater == true ? self.water.visibleReadings(multiSensor: self.multiSensorLevel) : []))
    }

    /// One annotation per reading, radiation before level as on the tab, which is also the order the label solver gives priority.
    static func annotations(radiation: [ProcessReading], water: [ProcessReading]) -> [MapAnnotationSnapshot] {
        return SensorAnnotations.radiation(radiation) + SensorAnnotations.water(water)
    }
}
