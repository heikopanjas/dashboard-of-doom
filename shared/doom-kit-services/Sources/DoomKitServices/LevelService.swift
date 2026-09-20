import DoomKitNetwork
import DoomKitTools
import Foundation

public class LevelService {
    public static func fetchStations(networkManager: NetworkManager = .shared) async throws -> Data? {
        trace.debug("Fetching level measurements stations...")
        let urlString = "https://www.pegelonline.wsv.de/webservices/rest-api/v2/stations.json"
        let result = await networkManager.performDataRequest(urlString: urlString)
        switch result {
            case .success(let data):
                trace.debug("Fetched level measurements stations.")
                return data
            case .failure(let error):
                trace.error("Failed to fetch level measurements stations: \(error.localizedDescription)")
                return nil
        }
    }

    public static func fetchMeasurements(for id: String, networkManager: NetworkManager = .shared) async throws -> Data? {
        trace.debug("Fetching water level measurements for station: \(id)")
        let urlString = "https://www.pegelonline.wsv.de/webservices/rest-api/v2/stations/\(id)/W/measurements.json?start=P3D"
        let result = await networkManager.performDataRequest(urlString: urlString)
        switch result {
            case .success(let data):
                trace.debug("Fetched water level measurements for station: \(id)")
                return data
            case .failure(let error):
                trace.error("Failed to fetch water level measurements for station: \(id): \(error.localizedDescription)")
                return nil
        }
    }

    public static func fetchForecast(for id: String, networkManager: NetworkManager = .shared) async throws -> Data? {
        trace.debug("Fetching water level forecast for station: \(id)")
        let urlString = "https://www.pegelonline.wsv.de/webservices/rest-api/v2/stations/\(id)/WV/measurements.json"
        let result = await networkManager.performDataRequest(urlString: urlString)
        switch result {
            case .success(let data):
                trace.debug("Fetched water level forecast for station: \(id)")
                return data
            case .failure(let error):
                trace.error("Failed to fetch water level forecast for station: \(id): \(error.localizedDescription)")
                return nil
        }
    }
}
