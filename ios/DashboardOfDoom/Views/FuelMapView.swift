import DoomKitProcess
import SwiftUI

/// The dearest, or cheapest, filling stations near the user, as a map at the top of the Energy tab.
///
/// A price on its own says how much; the map says where, which is the useful half. It renders nothing at all until an API key is stored
/// in Settings and stations have loaded, so the tab looks exactly as it did before then.
struct FuelMapView: View {
    @Environment(FuelPresenter.self) private var presenter
    @AppStorage(SourcePreferences.fuelTypeKey) private var fuelType: Int = FuelStation.Fuel.e5.rawValue
    @AppStorage(SourcePreferences.fuelOrderKey) private var order: Int = FuelMapView.Order.dearest.rawValue
    @AppStorage(SourcePreferences.fuelRadiusKey) private var radius: Int = SourcePreferences.fuelRadiusDefault

    /// Which end of the price range the map shows. The raw value is stored, so the order must not be renumbered.
    enum Order: Int, CaseIterable, Sendable {
        case dearest = 0
        case cheapest = 1

        var label: String {
            switch self {
                case .dearest:
                    return "Dearest"
                case .cheapest:
                    return "Cheapest"
            }
        }
    }

    /// How many stations the map shows. Six is what the label placement solver was built for.
    static let count = 6

    var body: some View {
        let fuel = FuelStation.Fuel(rawValue: self.fuelType) ?? .e5
        let order = Order(rawValue: self.order) ?? .dearest
        let annotations = Self.annotations(stations: self.presenter.stations, fuel: fuel, order: order)
        if annotations.isEmpty == false {
            VStack {
                SensorMapView(annotations: annotations)
                HStack {
                    // Crediting tankerkoenig.de and MTS-K is a condition of the CC BY licence, so it travels with the stations.
                    Text(
                        "\(order.label) \(fuel.label) within \(self.radius) km. Prices from tankerkoenig.de (CC BY 4.0), data from MTS-K."
                    )
                    .font(.footnote)
                    .foregroundColor(.gray)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 12)
            }
        }
    }

    /// One pin per ranked station. The id is the provider's own, so a station keeps its label placement across refreshes, and the rank
    /// rides in the icon so the price keeps the text slot at full size.
    static func annotations(stations: [FuelStation], fuel: FuelStation.Fuel, order: Order = .dearest) -> [MapAnnotationSnapshot] {
        return Self.ranked(stations: stations, fuel: fuel, order: order).enumerated().map { index, station in
            return MapAnnotationSnapshot(
                id: "fuel-\(station.id)", location: station.location, selector: .energy(.brent), icon: Self.rankIcon(index),
                faceplate: Self.priceString(station.price(for: fuel)), color: Self.color(index))
        }
    }

    /// One of the six home label colours per rank. There are exactly as many colours as the map shows stations; a longer list would
    /// wrap rather than run out.
    static func color(_ index: Int) -> Color {
        return Color.fuelStations[index % Color.fuelStations.count]
    }

    /// A numbered circle for the rank. SF Symbols only goes up to fifty, and nothing beyond nine is asked for here, so anything further
    /// falls back to the pump.
    static func rankIcon(_ index: Int) -> String {
        let rank = index + 1
        return (1 ... 9).contains(rank) ? "\(rank).circle.fill" : "fuelpump.fill"
    }

    /// The stations to show, at whichever end of the price range is asked for, and only those open right now, since a closed one cannot
    /// sell at any price. A station that does not sell this fuel has no price for it and does not appear.
    static func ranked(
        stations: [FuelStation], fuel: FuelStation.Fuel, order: Order = .dearest, limit: Int = FuelMapView.count
    ) -> [FuelStation] {
        let selling = stations.filter { $0.isOpen == true && $0.price(for: fuel) != nil }
        let ranked = selling.sorted { first, second in
            let one = first.price(for: fuel) ?? 0
            let other = second.price(for: fuel) ?? 0
            // The nearer of two equally priced stations comes first, so the order does not wobble between refreshes.
            if one == other {
                return first.distance < second.distance
            }
            return order == .dearest ? one > other : one < other
        }
        return Array(ranked.prefix(max(limit, 0)))
    }

    /// A price the way a German pump board writes it: a comma, and the tenth of a cent raised and small, as in 2,40\u{2079} €.
    static func priceString(_ price: Double?) -> String {
        guard let price = price, let parts = Self.parts(of: price) else { return "n/a" }
        return "\(parts.whole),\(String(format: "%02d", parts.cents))\(Self.superscripts[parts.tenth]) €"
    }

    /// Whole euros, whole cents and the tenth of a cent. Nil for a price no pump could show.
    static func parts(of price: Double) -> (whole: Int, cents: Int, tenth: Int)? {
        guard price.isFinite == true, price >= 0 else { return nil }
        let tenths = Int((price * 1000).rounded())
        return (whole: tenths / 1000, cents: (tenths % 1000) / 10, tenth: tenths % 10)
    }

    private static let superscripts = [
        "\u{2070}", "\u{00B9}", "\u{00B2}", "\u{00B3}", "\u{2074}", "\u{2075}", "\u{2076}", "\u{2077}", "\u{2078}", "\u{2079}"
    ]
}
