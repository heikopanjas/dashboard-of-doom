import DoomKitNetwork
import DoomKitTools
import Foundation

/// Oil production of the OPEC+ countries from AmericasOilWatch, which republishes EIA's international data as JSON with no key: per
/// country, the latest month and three years of monthly history in thousand barrels a day.
public class ProductionService {
    static let opecURL = "https://americasoilwatch.com/api/v1/opec"

    public static func fetchOPEC(networkManager: NetworkManager = .shared) async throws -> Data? {
        trace.debug("Fetching OPEC+ production...")
        let result = await networkManager.performDataRequest(urlString: Self.opecURL)
        switch result {
            case .success(let data):
                trace.debug("Fetched OPEC+ production.")
                return data
            case .failure(let error):
                trace.error("Failed to fetch OPEC+ production: \(error.localizedDescription)")
                return nil
        }
    }
}
