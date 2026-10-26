import SwiftUI

/// The stations the fuel map shows, listed under it: rank, address and all three prices, in the map's order and colours. The fuel the map
/// ranks by is set in bold, since its column decided the order. A fuel a station does not sell shows a dash.
struct FuelStationList: View {
    /// Already ranked, as the map has them (`FuelMapView.ranked`).
    let stations: [FuelStation]
    let fuel: FuelStation.Fuel

    var body: some View {
        #if os(macOS)
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
            GridRow {
                Text("")
                // The address column takes all the width the prices leave, so the list spans the map's width instead of floating in the
                // middle of it.
                Text("Address")
                    .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(FuelStation.Fuel.allCases, id: \.self) { fuel in
                    Text(fuel.label)
                        .gridColumnAlignment(.trailing)
                }
            }
            .font(.caption)
            .foregroundColor(.gray)
            ForEach(Array(self.stations.enumerated()), id: \.element.id) { index, station in
                GridRow {
                    Self.rank(index: index, station: station)
                    Self.address(station)
                    ForEach(FuelStation.Fuel.allCases, id: \.self) { fuel in
                        Text(Self.price(station, fuel))
                            .fontWeight(fuel == self.fuel ? .bold : .regular)
                            .monospacedDigit()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        #else
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(self.stations.enumerated()), id: \.element.id) { index, station in
                HStack(alignment: .top, spacing: 10) {
                    Self.rank(index: index, station: station)
                    VStack(alignment: .leading, spacing: 2) {
                        Self.address(station)
                        HStack(spacing: 14) {
                            ForEach(FuelStation.Fuel.allCases, id: \.self) { fuel in
                                Text("\(fuel.label) \(Self.price(station, fuel))")
                                    .fontWeight(fuel == self.fuel ? .bold : .regular)
                                    .monospacedDigit()
                            }
                        }
                        .font(.footnote)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        #endif
    }

    /// The pin's rank in the pin's colour, or the lock the map shows for a closed station.
    private static func rank(index: Int, station: FuelStation) -> some View {
        return Image(systemName: station.isOpen == true ? FuelMapView.rankIcon(index) : "lock.fill")
            .foregroundStyle(FuelMapView.color(index))
            .accessibilityLabel(station.isOpen == true ? "Rank \(index + 1)" : "Closed")
    }

    /// Street and number, then postcode and town, on one line; a station without a street shows its town, one without either its name.
    private static func address(_ station: FuelStation) -> some View {
        return Text(Self.addressLine(station))
    }

    static func addressLine(_ station: FuelStation) -> String {
        let parts = [station.address, station.town].compactMap { $0 }
        return parts.isEmpty == true ? station.name : parts.joined(separator: ", ")
    }

    static func price(_ station: FuelStation, _ fuel: FuelStation.Fuel) -> String {
        guard let price = station.price(for: fuel) else { return "\u{2013}" }
        return FuelMapView.priceString(price)
    }
}
