import DoomKitNetwork
import DoomKitTools
import Foundation

public class RadiationService {
    public static func fetchStations(networkManager: NetworkManager = .shared) async throws -> Data? {
        trace.debug("Fetching radiation measurement stations...")
        let urlString =
            "https://www.imis.bfs.de/ogc/opendata/ows?service=WFS&version=1.1.0&request=GetFeature&typeName=opendata:odlinfo_odl_1h_latest&outputFormat=application/json"
        let result = await networkManager.performDataRequest(urlString: urlString)
        switch result {
            case .success(let data):
                trace.debug("Fetched radiation measurement stations.")
                return data
            case .failure(let error):
                trace.error("Failed to fetch radiation measurement stations: \(error.localizedDescription)")
                return nil
        }
    }

    public static func fetchMeasurements(for id: String, networkManager: NetworkManager = .shared) async throws -> Data? {
        trace.debug("Fetching radiation measurements for station ID: \(id)")
        let urlString =
            "https://www.imis.bfs.de/ogc/opendata/ows?service=WFS&version=1.1.0&request=GetFeature&typeName=opendata:odlinfo_timeseries_odl_1h&outputFormat=application/json&viewparams=kenn:\(id)"
        let result = await networkManager.performDataRequest(urlString: urlString)
        switch result {
            case .success(let data):
                trace.debug("Fetched radiation measurements for station ID: \(id)")
                return data
            case .failure(let error):
                trace.error("Failed to fetch radiation measurements for station ID: \(id): \(error.localizedDescription)")
                return nil
        }
    }
}
