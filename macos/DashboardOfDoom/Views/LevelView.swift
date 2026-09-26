import DoomKitProcess
import Charts
import SwiftUI

/// The Level tab: the map of the gauges, then one card per gauge, nearest first. Up to six with Multiple Sensors on, else the nearest.
struct LevelView: View {
    @Environment(LevelPresenter.self) private var presenter
    @AppStorage(SourcePreferences.multiSensorLevelKey) private var multiSensor: Bool = false

    var body: some View {
        // The same readings for map and cards, trimmed here as well as in the fetch, so switching off takes effect at once.
        let readings = self.presenter.visibleReadings(multiSensor: self.multiSensor)
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                SensorMapView(annotations: SensorAnnotations.water(readings))
                if self.presenter.timestamp == nil {
                    ActivityIndicator()
                }
                else {
                    SensorCardGrid(readings: readings, colorSelector: .water(.level)) { reading in
                        ForEach(ProcessSelector.Water.allCases.filter { reading.isAvailable(selector: .water($0)) }, id: \.self) { selector in
                            VStack {
                                LevelChartView(reading: reading, selector: .water(selector))
                            }
                            .frame(height: 167)
                        }
                    }
                }
            }
        }
    }
}
