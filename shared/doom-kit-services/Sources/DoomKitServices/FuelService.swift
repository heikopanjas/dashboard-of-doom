import DoomKitLocation
import DoomKitNetwork
import DoomKitTools
import Foundation

/// Filling station prices from Tankerkoenig, which redistributes the Bundeskartellamt's MTS-K data under CC BY 4.0. Stations report a
/// price change within five minutes by law, so this is the authoritative source for German fuel prices.
///
/// The key is a parameter rather than something this reads for itself: the services package knows nothing of the app's keychain, and a
/// golden URL test needs a value it can reproduce.
public class FuelService {
    static let baseURL = "https://creativecommons.tankerkoenig.de/json/list.php"

    /// Every station within `radius` kilometres, with its prices for all three fuels.
    ///
    /// `sort` must be `dist` while `type` is `all`; the API rejects a request that asks for all fuels sorted by price, so any ranking is
    /// the caller's to do.
    public static func fetchStations(
        location: Location, radius: Double, apiKey: String, networkManager: NetworkManager = .shared
    ) async throws -> Data? {
        trace.debug("Fetching fuel stations...")
        let urlString =
            "\(Self.baseURL)?lat=\(location.latitude)&lng=\(location.longitude)&rad=\(radius)&sort=dist&type=all&apikey=\(apiKey)"
        let result = await networkManager.performDataRequest(urlString: urlString)
        switch result {
            case .success(let data):
                trace.debug("Fetched fuel stations.")
                return data
            case .failure(let error):
                trace.error("Failed to fetch fuel stations: \(error.localizedDescription)")
                return nil
        }
    }
}
