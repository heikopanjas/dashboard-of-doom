import DoomKitLocation
import Foundation

/// A filling station and what it charges, from Tankerkoenig's redistribution of the Bundeskartellamt's MTS-K price data.
struct FuelStation: Identifiable, Equatable, Sendable {
    /// What a station sells. The raw value is stored in the settings picker, so the order must not be renumbered.
    enum Fuel: Int, CaseIterable, Sendable {
        case e5 = 0
        case e10 = 1
        case diesel = 2

        var label: String {
            switch self {
                case .e5:
                    return "Super E5"
                case .e10:
                    return "E10"
                case .diesel:
                    return "Diesel"
            }
        }

        /// The field this price arrives in, which is also what the API calls the fuel type.
        var field: String {
            switch self {
                case .e5:
                    return "e5"
                case .e10:
                    return "e10"
                case .diesel:
                    return "diesel"
            }
        }
    }

    /// The provider's own id, stable across refreshes.
    let id: String
    let name: String
    let brand: String?
    let street: String?
    let houseNumber: String?
    /// Where the station is, so it can be put on a map.
    let location: Location
    /// Kilometres from the user, as the API reports it.
    let distance: Double
    let isOpen: Bool
    /// One entry per fuel the station sells; a station that does not sell a fuel has no entry for it.
    let prices: [Fuel: Double]

    func price(for fuel: Fuel) -> Double? {
        return self.prices[fuel]
    }

    /// Street and house number, when the station gave them.
    var address: String? {
        let street = self.street?.trimmingCharacters(in: .whitespaces) ?? ""
        guard street.isEmpty == false else { return nil }
        let number = self.houseNumber?.trimmingCharacters(in: .whitespaces) ?? ""
        return number.isEmpty == true ? street : "\(street) \(number)"
    }
}
