import DoomKitLocation
import DoomKitNetwork
import DoomKitTools
import Foundation

/// European energy prices from public endpoints that need no key.
///
/// EuroOilWatch supplies Brent spot history (EIA), Brent futures and TTF futures (Yahoo Finance) as JSON. Liquefied natural gas comes
/// from ACER, the EU energy regulator, which has published a daily LNG price for Europe since 2023 as CSV.
public class EnergyService {
    static let brentURL = "https://eurooilwatch.com/api/v1/brent"
    static let brentHistoryURL = "https://eurooilwatch.com/api/v1/brent-history"
    static let lngURL = "https://aegis.acer.europa.eu/terminal/price_assessments/historical_data"

    public static func fetchBrent(networkManager: NetworkManager = .shared) async throws -> Data? {
        return await Self.fetch(name: "Brent crude prices", urlString: Self.brentURL, networkManager: networkManager)
    }

    public static func fetchBrentHistory(networkManager: NetworkManager = .shared) async throws -> Data? {
        return await Self.fetch(name: "Brent futures history", urlString: Self.brentHistoryURL, networkManager: networkManager)
    }

    public static func fetchBrentSpot(networkManager: NetworkManager = .shared) async throws -> Data? {
        return await Self.fetch(
            name: "Brent spot prices", urlString: "https://eurooilwatch.com/api/v1/brent-eia-daily", networkManager: networkManager)
    }

    public static func fetchGas(networkManager: NetworkManager = .shared) async throws -> Data? {
        return await Self.fetch(name: "TTF futures", urlString: "https://eurooilwatch.com/api/v1/gas", networkManager: networkManager)
    }

    public static func fetchLNG(networkManager: NetworkManager = .shared) async throws -> Data? {
        return await Self.fetch(name: "EU LNG prices", urlString: Self.lngURL, networkManager: networkManager)
    }

    private static func fetch(name: String, urlString: String, networkManager: NetworkManager) async -> Data? {
        trace.debug("Fetching \(name)...")
        let result = await networkManager.performDataRequest(urlString: urlString)
        switch result {
            case .success(let data):
                trace.debug("Fetched \(name).")
                return data
            case .failure(let error):
                trace.error("Failed to fetch \(name): \(error.localizedDescription)")
                return nil
        }
    }
}
