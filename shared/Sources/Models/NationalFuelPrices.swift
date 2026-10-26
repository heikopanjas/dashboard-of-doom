import Foundation

/// The week's average pump prices including taxes in Germany and across the EU, from the European Commission's Weekly Oil Bulletin via
/// EuroOilWatch, in euros per litre. Petrol is Euro-super 95, which is E5; the bulletin has no E10.
struct NationalFuelPrices: Equatable, Sendable {
    /// The date the bulletin's prices refer to, `yyyy-MM-dd`.
    let bulletinDate: String
    let petrol: Double
    let diesel: Double
    let euPetrol: Double?
    let euDiesel: Double?
}
