import DoomKitProcess
import SwiftUI

/// The Energy screen, fuel in Germany. The fuel station map and its list sit above it (`ContentView`); this is this week's national average
/// prices and Germany's monthly fuel stocks. The world market prices are on Energy Markets.
struct EnergyView: View {
    @Environment(FuelStockPresenter.self) private var stocks

    var body: some View {
        VStack {
            // The national yardstick for the stations above; it needs no key, so it shows without them too.
            if let national = self.stocks.readings.first?.sensor.customData?["nationalPrices"] as? NationalFuelPrices {
                NationalFuelPricesView(prices: national)
                    .padding(.horizontal, 5)
                Divider()
                    .padding(.horizontal, 5)
                    .padding(.trailing, 5)
                    .padding(.vertical, 6)
            }
            if let reading = self.stocks.readings.first {
                EnergySectionHeader(
                    title: "Fuel Stocks in Germany", symbol: "shippingbox", placemark: reading.sensor.placemark,
                    timestamp: reading.sensor.timestamp)
                EnergyChartList(reading: reading, selectors: ProcessSelector.Energy.stocks)
            }
            else {
                ActivityIndicator()
            }
        }
    }
}
