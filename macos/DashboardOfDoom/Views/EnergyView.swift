import Charts
import DoomKitProcess
import SwiftUI

/// The Energy screen, fuel in Germany: the fuel station map with its list of the same stations, this week's national average prices, then
/// Germany's monthly fuel stocks. The world market prices are on Energy Markets.
struct EnergyView: View {
    @Environment(FuelStockPresenter.self) private var stocks

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                // Renders nothing until a Tankerkoenig key is stored and stations have loaded.
                FuelMapView()

                // The national yardstick for the stations above; it needs no key, so it shows without them too.
                if let national = self.stocks.readings.first?.sensor.customData?["nationalPrices"] as? NationalFuelPrices {
                    NationalFuelPricesView(prices: national)
                    Divider()
                        .padding(.vertical, 8)
                }

                HStack {
                    Image(systemName: "shippingbox")
                    Text("Fuel Stocks in Germany")
                }
                .font(.headline)

                if let reading = self.stocks.readings.first {
                    EnergySourceRow(placemark: reading.sensor.placemark, timestamp: reading.sensor.timestamp)
                    EnergyChartGrid(reading: reading, selectors: ProcessSelector.Energy.stocks)
                }
                else {
                    ActivityIndicator()
                }
            }
        }
    }
}
