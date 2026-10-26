import DoomKitNetwork
import DoomKitTools
import Foundation

public class LevelService {
    public static func fetchStations(networkManager: NetworkManager = .shared) async throws -> Data? {
        trace.debug("Fetching level measurements stations...")
        // Only stations with a water level series: the list also holds gauges that measure only clearance height or discharge, and the
        // nearest of those (Koblenz-Lützel DFH, beside the Rhine gauge) gave the Level tab a gauge with nothing to show.
        let urlString = "https://www.pegelonline.wsv.de/webservices/rest-api/v2/stations.json?timeseries=W"
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

    /// The station with its time series and their characteristic values: mean and flood levels, and where the state publishes them, the
    /// flood reporting stages. About 2 KB per gauge; the full station list with them is 1.3 MB, so it is fetched per gauge. With
    /// `includeForecast` the list of time series also names the water level forecast, `WV`, where the gauge has one, which is how a gauge
    /// with a forecast is told from the many without one before asking for it.
    public static func fetchCharacteristics(
        for id: String, includeForecast: Bool = false, networkManager: NetworkManager = .shared
    ) async throws -> Data? {
        trace.debug("Fetching water level characteristics for station: \(id)")
        let forecast = includeForecast ? "&includeForecastTimeseries=true" : ""
        let urlString =
            "https://www.pegelonline.wsv.de/webservices/rest-api/v2/stations/\(id).json?includeTimeseries=true&includeCharacteristicValues=true\(forecast)"
        let result = await networkManager.performDataRequest(urlString: urlString)
        switch result {
            case .success(let data):
                trace.debug("Fetched water level characteristics for station: \(id)")
                return data
            case .failure(let error):
                trace.error("Failed to fetch water level characteristics for station: \(id): \(error.localizedDescription)")
                return nil
        }
    }

    /// The gauge's current water level forecast run: values in cm on the same gauge zero as the readings, typed `forecast` for the first
    /// days and `estimate` after that, some with a 10 and 90 percentile. A gauge without a forecast answers 404.
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
