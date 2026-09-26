import DoomKitProcess
import Charts
import SwiftUI

/// The Radiation tab: the map of the stations, then one card per station, nearest first. Up to six with Multiple Sensors on, else the
/// nearest.
struct RadiationView: View {
    @Environment(RadiationPresenter.self) private var presenter
    @AppStorage(SourcePreferences.multiSensorRadiationKey) private var multiSensor: Bool = false

    var body: some View {
        // The same readings for map and cards, trimmed here as well as in the fetch, so switching off takes effect at once.
        let readings = self.presenter.visibleReadings(multiSensor: self.multiSensor)
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                SensorMapView(annotations: SensorAnnotations.radiation(readings))
                if self.presenter.timestamp == nil {
                    ActivityIndicator()
                }
                else {
                    SensorCardGrid(readings: readings, colorSelector: .radiation(.total)) { reading in
                        ForEach(
                            ProcessSelector.Radiation.allCases.filter { reading.isAvailable(selector: .radiation($0)) }, id: \.self
                        ) { selector in
                            VStack {
                                RadiationChartView(reading: reading, selector: .radiation(selector))
                            }
                            .frame(height: 167)
                        }
                    }
                    // The BfS data licence asks for its source note next to the data.
                    Text(DataSources.radiationNote)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
    }
}
