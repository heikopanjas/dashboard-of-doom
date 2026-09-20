import DoomKitLocation
import DoomKitNetwork
import DoomKitTools
import Foundation

/// Global energy prices, as CSV files that need no key.
///
/// Crude oil comes from the `datasets/oil-prices` project, which republishes the US Energy Information Administration's daily Brent and
/// WTI spot prices under a public domain licence; the EIA's own API would need a key. Liquefied natural gas comes from ACER, the EU energy
/// regulator, which has published a daily LNG price for Europe since 2023.
public class EnergyService {
    static let brentURL = "https://raw.githubusercontent.com/datasets/oil-prices/main/data/brent-daily.csv"
    static let wtiURL = "https://raw.githubusercontent.com/datasets/oil-prices/main/data/wti-daily.csv"
    static let lngURL = "https://aegis.acer.europa.eu/terminal/price_assessments/historical_data"

    public static func fetchBrent(networkManager: NetworkManager = .shared) async throws -> Data? {
        return await Self.fetch(name: "Brent crude prices", urlString: Self.brentURL, networkManager: networkManager)
    }

    public static func fetchWTI(networkManager: NetworkManager = .shared) async throws -> Data? {
        return await Self.fetch(name: "WTI crude prices", urlString: Self.wtiURL, networkManager: networkManager)
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
