import DoomKitProcess
import SwiftUI

/// The Energy Markets screen below its map (`ProducerMapView`, placed by `ContentView` like the other source maps): the futures and spot
/// prices Europe pays for oil and gas, then each Gulf producer's production as a chart.
struct EnergyMarketsView: View {
    @ScaledMetric(relativeTo: .body) private var chartHeight = 167.0
    @Environment(EnergyPresenter.self) private var prices
    @Environment(ProducerPresenter.self) private var producers

    var body: some View {
        VStack {
            if let reading = self.prices.readings.first {
                EnergySectionHeader(
                    title: "Futures and Spot Prices", symbol: "chart.line.uptrend.xyaxis", placemark: reading.sensor.placemark,
                    timestamp: reading.sensor.timestamp)
                EnergyChartList(reading: reading, selectors: ProcessSelector.Energy.prices)
            }
            else {
                ActivityIndicator()
            }

            Divider()
                .padding(.horizontal, 5)
                .padding(.trailing, 5)
            EnergySectionHeader(
                title: "OPEC+ Production in the Gulf", symbol: "drop.fill", placemark: "EIA via AmericasOilWatch",
                timestamp: self.producers.readings.first?.sensor.timestamp)
            if self.producers.readings.isEmpty == true {
                ActivityIndicator()
            }
            else {
                if let explainer = EnergyExplainers.text[.energy(.production)] {
                    EnergyExplainerText(text: explainer)
                }
                // Keyed by the country code, so a country keeps its identity, and its drag selection, across refreshes.
                ForEach(Array(self.producers.readings.enumerated()), id: \.element.id) { index, reading in
                    if index > 0 {
                        Divider()
                            .padding(.horizontal, 5)
                            .padding(.trailing, 5)
                    }
                    // Every country is titled with its name, as the nearest sensor is with its address elsewhere.
                    SensorHeaderView(reading: reading, isNearest: true, color: Color.sensor(selector: .energy(.production), index: index))
                    VStack {
                        EnergyChartView(reading: reading, selector: .energy(.production))
                    }
                    .padding(.vertical, 5)
                    .frame(height: self.chartHeight)
                }
            }
        }
    }
}
