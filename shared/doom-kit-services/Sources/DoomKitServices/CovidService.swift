import DoomKitLocation
import DoomKitNetwork
import DoomKitTools
import Foundation

public class CovidService {
    public static func fetchDistricts(for location: Location, radius: Double, networkManager: NetworkManager = .shared) async throws -> Data? {
        let box = calculateBoundingBox(center: location, radiusInMeters: radius)
        let urlString =
            "https://sgx.geodatenzentrum.de/wfs_vg250?service=WFS&version=2.0.0&request=GetFeature"
            + "&typeNames=vg250:vg250_krs"
            + "&bbox=\(box.minLongitude),\(box.minLatitude),\(box.maxLongitude),\(box.maxLatitude),EPSG:4326"
            + "&outputFormat=application/json&count=20"

        trace.debug("Fetching covid districts near location: \(location.latitude), \(location.longitude), radius: \(radius)m")

        let networkStatus = await networkManager.isConnected
        trace.debug("Network status before districts request: \(networkStatus ? "connected" : "disconnected")")

        let result = await networkManager.performDataRequest(urlString: urlString)
        switch result {
            case .success(let data):
                trace.debug("Fetched covid districts successfully, data size: \(data.count) bytes")
                return data
            case .failure(let error):
                let networkStatusAfter = await networkManager.isConnected
                trace.error("Failed to fetch covid districts - Error: \(error)")
                trace.error("  Location: \(location.latitude), \(location.longitude), radius: \(radius)m")
                trace.error("  Network before: \(networkStatus), after: \(networkStatusAfter)")
                trace.error("  URL length: \(urlString.count) chars")
                return nil
        }
    }

    public static func fetchIncidence(id: String, duration: Double = 100.0, networkManager: NetworkManager = .shared) async throws -> Data? {
        trace.debug("Fetching covid incidence for district: \(id)")
        let urlString = "https://api.corona-zahlen.org/districts/\(id)/history/incidence/\(Int(duration))"
        let result = await networkManager.performDataRequest(urlString: urlString)
        switch result {
            case .success(let data):
                trace.debug("Fetched covid incidence for district: \(id)")
                return data
            case .failure(let error):
                trace.error("Failed to fetch covid incidence for district: \(id): \(error.localizedDescription)")
                return nil
        }
    }

    public static func fetchCases(id: String, duration: Double = 100.0, networkManager: NetworkManager = .shared) async throws -> Data? {
        trace.debug("Fetching covid cases for district: \(id)")
        let urlString = "https://api.corona-zahlen.org/districts/\(id)/history/cases/\(Int(duration))"
        let result = await networkManager.performDataRequest(urlString: urlString)
        switch result {
            case .success(let data):
                trace.debug("Fetched covid cases for district: \(id)")
                return data
            case .failure(let error):
                trace.error("Failed to fetch covid cases for district: \(id): \(error.localizedDescription)")
                return nil
        }
    }

    public static func fetchDeaths(id: String, duration: Double = 100.0, networkManager: NetworkManager = .shared) async throws -> Data? {
        trace.debug("Fetching covid deaths for district: \(id)")
        let urlString = "https://api.corona-zahlen.org/districts/\(id)/history/deaths/\(Int(duration))"
        let result = await networkManager.performDataRequest(urlString: urlString)
        switch result {
            case .success(let data):
                trace.debug("Fetched covid deaths for district: \(id)")
                return data
            case .failure(let error):
                trace.error("Failed to fetch covid deaths for district: \(id): \(error.localizedDescription)")
                return nil
        }
    }

    public static func fetchRecovered(id: String, duration: Double = 100.0, networkManager: NetworkManager = .shared) async throws -> Data? {
        trace.debug("Fetching covid recovered for district: \(id)")
        let urlString = "https://api.corona-zahlen.org/districts/\(id)/history/recovered/\(Int(duration))"
        let result = await networkManager.performDataRequest(urlString: urlString)
        switch result {
            case .success(let data):
                trace.debug("Fetched covid recovered for district: \(id)")
                return data
            case .failure(let error):
                trace.error("Failed to fetch covid recovered for district: \(id): \(error.localizedDescription)")
                return nil
        }
    }
}
