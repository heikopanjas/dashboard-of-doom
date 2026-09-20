import DoomKitLocation
import DoomKitNetwork
import DoomKitTools
import Foundation

public class SurveyService {
    public static func fetchStates(for location: Location, networkManager: NetworkManager = .shared) async throws -> Data? {
        let query =
            "[out:json][timeout:25];relation(around:10000,\(location.latitude),\(location.longitude))[\"boundary\"=\"administrative\"][\"admin_level\"=\"4\"];out center tags;"

        // URL encode the query and construct proper API endpoint
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            trace.error("Failed to encode Overpass query")
            return nil
        }

        let urlString = "https://overpass-api.de/api/interpreter?data=\(encodedQuery)"

        trace.debug("Fetching federal states...")
        let result = await networkManager.performDataRequest(urlString: urlString)
        switch result {
            case .success(let data):
                trace.debug("Fetched federal states.")
                return data
            case .failure(let error):
                trace.error("Failed to fetch federal states: \(error.localizedDescription)")
                return nil
        }
    }

    public static func fetchPolls(networkManager: NetworkManager = .shared) async throws -> Data? {
        trace.debug("Fetching election polls...")
        let urlString = "https://api.dawum.de"
        let result = await networkManager.performDataRequest(urlString: urlString)
        switch result {
            case .success(let data):
                trace.debug("Fetched election polls.")
                return data
            case .failure(let error):
                trace.error("Failed to fetch election polls: \(error.localizedDescription)")
                return nil
        }
    }
}
