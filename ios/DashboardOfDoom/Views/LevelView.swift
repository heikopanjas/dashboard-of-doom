import DoomKitProcess
import DoomKitLocation
import DoomKitTools
import Charts
import SwiftUI

struct LevelView: View {
    @ScaledMetric(relativeTo: .body) private var chartHeight = 167.0
    @Environment(LevelPresenter.self) private var presenter
    @AppStorage(SourcePreferences.multiSensorLevelKey) private var multiSensor: Bool = false

    var body: some View {
        VStack {
            if presenter.timestamp == nil {
                ActivityIndicator()
            }
            else {
                // Keyed by the source id, so a gauge keeps its identity, and its drag selection, across refreshes.
                ForEach(Array(self.presenter.visibleReadings(multiSensor: self.multiSensor).enumerated()), id: \.element.id) { index, reading in
                    if index > 0 {
                        Divider()
                            .padding(.horizontal, 5)
                            .padding(.trailing, 5)
                    }
                    SensorHeaderView(reading: reading, isNearest: index == 0, color: Color.sensor(selector: .water(.level), index: index))

                    ForEach(ProcessSelector.Water.allCases, id: \.self) { selector in
                        if reading.isAvailable(selector: .water(selector)) {
                            VStack {
                                LevelChartView(selector: .water(selector), reading: reading)
                            }
                            .padding(.vertical, 5)
                            .frame(height: self.chartHeight)
                        }
                    }
                }
            }
        }
    }
}
