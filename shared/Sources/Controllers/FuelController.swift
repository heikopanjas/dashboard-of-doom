import DoomKitLocation
import DoomKitNetwork
import DoomKitSecrets
import DoomKitServices
import DoomKitTools
import Foundation

/// The filling stations around the user. Needs a Tankerkoenig API key, which the user pastes into Settings; without one it asks for
/// nothing at all.
struct FuelController {
    /// The name the key is filed under in the keychain.
    static let apiKeyName = SecretKey(name: "tankerkoenig-api-key")

    private let networkManager: NetworkManager
    private let apiKey: @Sendable () -> String?
    private let radius: @Sendable () -> Double

    init(
        networkManager: NetworkManager = .shared,
        apiKey: @escaping @Sendable () -> String? = { return try? AppSecrets.shared.read(FuelController.apiKeyName) },
        radius: @escaping @Sendable () -> Double = { return SourcePreferences.fuelRadius() }
    ) {
        self.networkManager = networkManager
        self.apiKey = apiKey
        self.radius = radius
    }

    func fetchStations(location: Location) async throws -> [FuelStation] {
        // No key, no request: the source stays silent until one is stored.
        guard let key = self.apiKey(), key.isEmpty == false else {
            return []
        }
        try Task.checkCancellation()
        guard
            let data = try await FuelService.fetchStations(
                location: location, radius: self.radius(), apiKey: key, networkManager: self.networkManager)
        else {
            return []
        }
        try Task.checkCancellation()
        return try Self.parseStations(from: data)
    }

    /// The stations of a response, in the order the API gave them. A response the API itself marked as failed carries a message rather
    /// than stations, so it yields nothing.
    static func parseStations(from data: Data) throws -> [FuelStation] {
        guard let json = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) as? [String: Any] else {
            return []
        }
        if json["ok"] as? Bool != true {
            trace.error("Fuel station request refused: \(json["message"] as? String ?? "unknown reason")")
            return []
        }
        guard let entries = json["stations"] as? [[String: Any]] else {
            return []
        }
        var stations: [FuelStation] = []
        for entry in entries {
            if let station = Self.parseStation(from: entry) {
                stations.append(station)
            }
        }
        return stations
    }

    private static func parseStation(from entry: [String: Any]) -> FuelStation? {
        guard let id = entry["id"] as? String, let name = entry["name"] as? String else {
            return nil
        }
        // A station without coordinates cannot go on the map, which is the only place they are shown.
        guard let latitude = entry["lat"] as? Double, let longitude = entry["lng"] as? Double else {
            return nil
        }
        var prices: [FuelStation.Fuel: Double] = [:]
        for fuel in FuelStation.Fuel.allCases {
            // A station that does not sell a fuel reports it as null, and a price of zero is not a price.
            if let price = entry[fuel.field] as? Double, price > 0 {
                prices[fuel] = price
            }
        }
        guard prices.isEmpty == false else {
            return nil
        }
        return FuelStation(
            id: id, name: name, brand: entry["brand"] as? String, street: entry["street"] as? String,
            houseNumber: entry["houseNumber"] as? String, location: Location(latitude: latitude, longitude: longitude),
            distance: entry["dist"] as? Double ?? 0, isOpen: entry["isOpen"] as? Bool ?? false, prices: prices)
    }
}
