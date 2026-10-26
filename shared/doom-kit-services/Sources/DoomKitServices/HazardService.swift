import DoomKitNetwork
import DoomKitTools
import Foundation

/// The NINA list feeds. MoWaS is civil protection, DWD is weather,
/// KATWARN and BIWAPP carry local municipal alerts.
public enum HazardFeed: String, CaseIterable, Sendable {
    case mowas, dwd, katwarn, biwapp
}

public class HazardService {
    static let baseURL = "https://warnung.bund.de/api31"

    public static func fetchHazardList(feed: HazardFeed, networkManager: NetworkManager = .shared) async throws -> Data? {
        trace.debug("Fetching \(feed.rawValue) hazards...")
        let result = await networkManager.performDataRequest(urlString: "\(Self.baseURL)/\(feed.rawValue)/mapData.json")
        switch result {
            case .success(let data):
                trace.debug("Fetched \(feed.rawValue) hazards.")
                return data
            case .failure(let error):
                trace.error("Failed to fetch \(feed.rawValue) hazards: \(error.localizedDescription)")
                return nil
        }
    }

    public static func fetchHazardDetails(for alertId: String, networkManager: NetworkManager = .shared) async throws -> Data? {
        trace.debug("Fetching hazard details...")
        let result = await networkManager.performDataRequest(urlString: "\(Self.baseURL)/warnings/\(Self.path(alertId)).json")
        switch result {
            case .success(let data):
                trace.debug("Fetched hazard details.")
                return data
            case .failure(let error):
                trace.error("Failed to fetch hazard details: \(error.localizedDescription)")
                return nil
        }
    }

    public static func fetchHazardRegion(for alertId: String, networkManager: NetworkManager = .shared) async throws -> Data? {
        trace.debug("Fetching hazard region...")
        let result = await networkManager.performDataRequest(urlString: "\(Self.baseURL)/warnings/\(Self.path(alertId)).geojson")
        switch result {
            case .success(let data):
                trace.debug("Fetched hazard region.")
                return data
            case .failure(let error):
                trace.error("Failed to fetch hazard region: \(error.localizedDescription)")
                return nil
        }
    }

    private static func path(_ id: String) -> String {
        return id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
    }
}
