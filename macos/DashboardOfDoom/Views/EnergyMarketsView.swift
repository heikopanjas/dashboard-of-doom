import Charts
import DoomKitProcess
import SwiftUI

/// The Energy Markets screen: the map of the Gulf producers on top, then the futures and spot prices Europe pays for oil and gas, then each
/// producer's production as a chart.
struct EnergyMarketsView: View {
    @Environment(EnergyPresenter.self) private var prices
    @Environment(ProducerPresenter.self) private var producers

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                // Renders nothing until the producers have loaded, like the other source maps.
                ProducerMapView()

                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("Futures and Spot Prices")
                }
                .font(.headline)
                if let reading = self.prices.readings.first {
                    EnergySourceRow(placemark: reading.sensor.placemark, timestamp: reading.sensor.timestamp)
                    EnergyChartGrid(reading: reading, selectors: ProcessSelector.Energy.prices)
                }
                else {
                    ActivityIndicator()
                }

                Divider()
                    .padding(.vertical, 8)
                HStack {
                    Image(systemName: "drop.fill")
                    Text("OPEC+ Production in the Gulf")
                }
                .font(.headline)
                if self.producers.readings.isEmpty == true {
                    ActivityIndicator()
                }
                else {
                    if let explainer = EnergyExplainers.text[.energy(.production)] {
                        Text(explainer)
                            .font(.footnote)
                            .foregroundColor(.gray)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    SensorCardGrid(readings: self.producers.readings, colorSelector: .energy(.production), titlesFromPlacemark: true) {
                        reading in
                        VStack {
                            EnergyChartView(reading: reading, selector: .energy(.production))
                        }
                        .frame(height: 167)
                    }
                }
            }
        }
    }
}
