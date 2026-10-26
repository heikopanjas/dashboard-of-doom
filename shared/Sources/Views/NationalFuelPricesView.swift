import SwiftUI

/// This week's average pump prices in Germany next to the EU's, from the EU Weekly Oil Bulletin, as a yardstick for the stations on the
/// map. Prices are written the way the map writes them, and petrol is E5, the only petrol the bulletin reports.
struct NationalFuelPricesView: View {
    let prices: NationalFuelPrices

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "eurosign.circle")
                Text("Germany This Week")
                Spacer()
            }
            .font(.headline)
            .accentLabel()
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 4) {
                GridRow {
                    Text("")
                    Text("Germany")
                        .gridColumnAlignment(.trailing)
                    Text("EU Average")
                        .gridColumnAlignment(.trailing)
                }
                .font(.caption)
                .foregroundColor(.gray)
                Self.row(label: "Super E5", germany: self.prices.petrol, europe: self.prices.euPetrol)
                Self.row(label: "Diesel", germany: self.prices.diesel, europe: self.prices.euDiesel)
            }
            Text(
                "Average pump prices including taxes for the week of \(Self.dateText(self.prices.bulletinDate)), from the European Commission's Weekly Oil Bulletin via EuroOilWatch. The bulletin has no E10."
            )
            .font(.footnote)
            .foregroundColor(.gray)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static func row(label: String, germany: Double, europe: Double?) -> some View {
        return GridRow {
            Text(label)
            Text(FuelMapView.priceString(germany))
                .fontWeight(.semibold)
                .monospacedDigit()
            Text(europe.map { FuelMapView.priceString($0) } ?? "\u{2013}")
                .monospacedDigit()
        }
    }

    /// `2026-10-19` as a short date in the reader's language; the raw text when it does not parse. Formatted in UTC, where the parsed
    /// midnight lies, so a reader west of Greenwich does not see the day before.
    static func dateText(_ text: String) -> String {
        guard let date = EnergyController.date(from: text) else { return text }
        var style = Date.FormatStyle.dateTime.day().month(.abbreviated).year()
        style.timeZone = .gmt
        return date.formatted(style)
    }
}
