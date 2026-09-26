import DoomKitProcess
import Charts
import SwiftUI

/// The Particles tab: the map of the stations, then one section per station, nearest first, each with its header and the two-column grid
/// of the pollutants it reports. Up to six stations with Multiple Sensors on, else the nearest.
struct ParticleView: View {
    @Environment(ParticlePresenter.self) private var presenter
    @AppStorage(SourcePreferences.multiSensorParticlesKey) private var multiSensor: Bool = false

    var body: some View {
        // The same readings for map and sections, trimmed here as well as in the fetch, so switching off takes effect at once.
        let readings = self.presenter.visibleReadings(multiSensor: self.multiSensor)
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                SensorMapView(annotations: SensorAnnotations.particles(readings))
                if self.presenter.timestamp == nil {
                    ActivityIndicator()
                }
                else {
                    ForEach(Array(readings.enumerated()), id: \.element.id) { index, reading in
                        if index > 0 {
                            Divider()
                        }
                        SensorHeaderView(
                            reading: reading, isNearest: index == 0, color: Color.sensor(selector: .particle(.pm10), index: index))
                        let selectors = ProcessSelector.Particle.allCases.filter { reading.isAvailable(selector: .particle($0)) }
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            ForEach(selectors, id: \.self) { selector in
                                VStack {
                                    ParticleChartView(reading: reading, selector: .particle(selector))
                                }
                                .frame(height: 167)
                            }
                        }
                    }
                }
            }
        }
    }
}
