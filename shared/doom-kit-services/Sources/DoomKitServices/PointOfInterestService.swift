import DoomKitLocation
import DoomKitNetwork
import DoomKitTools
import Foundation

public class PointOfInterestService {
    //[out:json][timeout:25][bbox:52.47099,13.36611,52.56901,13.44389];
    //(
    //    node["amenity"="pharmacy"](around:5000, 52.5199, 13.3652);
    //    way["amenity"="pharmacy"](around:5000, 52.5199, 13.3652);
    //)->.pharmacies;
    //.pharmacies out center tags qt;
    public static func fetchPharmacies(location: Location, radius: Double, networkManager: NetworkManager = .shared) async throws -> Data? {
        let box = calculateBoundingBox(center: location, radiusInMeters: radius)
        let query =
            """
            [out:json][timeout:25][bbox:\(box.minLatitude),\(box.minLongitude),\(box.maxLatitude),\(box.maxLongitude)];
            (
                node["amenity"="pharmacy"](around:\(radius),\(location.latitude),\(location.longitude));
                way["amenity"="pharmacy"](around:\(radius),\(location.latitude),\(location.longitude));
            )->.pharmacies;
            .pharmacies out center tags qt;
            """
        guard
            let urlString = "https://overpass-api.de/api/interpreter?data=\(query)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        else {
            return nil
        }
        trace.debug("Fetching nearby pharmacies...")
        let result = await networkManager.performDataRequest(urlString: urlString, priority: .background)
        switch result {
            case .success(let data):
                trace.debug("Fetched nearby pharmacies.")
                return data
            case .failure(let error):
                trace.error("Failed to fetch nearby pharmacies: \(error.localizedDescription)")
                return nil
        }
    }

    //[out:json][timeout:25][bbox:52.47099,13.36611,52.56901,13.44389];
    //(
    //    node["amenity"="hospital"](around:5000, 52.5199, 13.3652);
    //    way["amenity"="hospital"](around:5000, 52.5199, 13.3652);
    //)->.hospitals;
    //.hospitals out center tags qt;
    public static func fetchHospitals(location: Location, radius: Double, networkManager: NetworkManager = .shared) async throws -> Data? {
        let box = calculateBoundingBox(center: location, radiusInMeters: radius)
        let query =
            """
            [out:json][timeout:25][bbox:\(box.minLatitude),\(box.minLongitude),\(box.maxLatitude),\(box.maxLongitude)];
            (
                node["amenity"="hospital"](around:\(radius),\(location.latitude),\(location.longitude));
                way["amenity"="hospital"](around:\(radius),\(location.latitude),\(location.longitude));
            )->.hospitals;
            .hospitals out center tags qt;
            """
        guard
            let urlString = "https://overpass-api.de/api/interpreter?data=\(query)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        else {
            return nil
        }
        trace.debug("Fetching nearby hospitals...")
        let result = await networkManager.performDataRequest(urlString: urlString, priority: .background)
        switch result {
            case .success(let data):
                trace.debug("Fetched nearby hospitals.")
                return data
            case .failure(let error):
                trace.error("Failed to fetch nearby hospitals: \(error.localizedDescription)")
                return nil
        }
    }

    //    [out:json][timeout:25][bbox:52.47099,13.36611,52.56901,13.44389];
    //    (
    //        node["shop"="convenience"](around:5000, 52.5199, 13.3652);
    //        way["shop"="convenience"](around:5000, 52.5199, 13.3652);
    //        node["shop"="alcohol"](around:5000, 52.5199, 13.3652);
    //        way["shop"="alcohol"](around:5000, 52.5199, 13.3652);
    //        node["shop"="beverages"](around:5000, 52.5199, 13.3652);
    //        way["shop"="beverages"](around:5000, 52.5199, 13.3652);
    //    )->.spatis;
    //    .spatis out center tags qt;
    public static func fetchLiquorStores(location: Location, radius: Double, networkManager: NetworkManager = .shared) async throws -> Data? {
        let box = calculateBoundingBox(center: location, radiusInMeters: radius)
        let query =
            """
            [out:json][timeout:25][bbox:\(box.minLatitude),\(box.minLongitude),\(box.maxLatitude),\(box.maxLongitude)];
            (
                node["shop"="convenience"](around:\(radius),\(location.latitude),\(location.longitude));
                way["shop"="convenience"](around:\(radius),\(location.latitude),\(location.longitude));
                node["shop"="alcohol"](around:\(radius),\(location.latitude),\(location.longitude));
                way["shop"="alcohol"](around:\(radius),\(location.latitude),\(location.longitude));
                node["shop"="beverages"](around:\(radius),\(location.latitude),\(location.longitude));
                way["shop"="beverages"](around:\(radius),\(location.latitude),\(location.longitude));
            )->.spatis;
            .spatis out center tags qt;
            """
        guard
            let urlString = "https://overpass-api.de/api/interpreter?data=\(query)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        else {
            return nil
        }
        trace.debug("Fetching nearby liquor stores...")
        let result = await networkManager.performDataRequest(urlString: urlString, priority: .background)
        switch result {
            case .success(let data):
                trace.debug("Fetched nearby liquor stores.")
                return data
            case .failure(let error):
                trace.error("Failed to fetch nearby liquor stores: \(error.localizedDescription)")
                return nil
        }
    }

    //[out:json][timeout:25][bbox:52.47099,13.36611,52.56901,13.44389];
    //(
    //    node["shop"="funeral_directors"](around:5000, 52.5199, 13.3652);
    //    way["shop"="funeral_directors"](around:5000, 52.5199, 13.3652);
    //    node["amenity"="funeral_hall"](around:5000, 52.5199, 13.3652);
    //    way["amenity"="funeral_hall"](around:5000, 52.5199, 13.3652);
    //)->.funeral_homes;
    //.funeral_homes out center tags qt;
    public static func fetchFuneralDirectors(location: Location, radius: Double, networkManager: NetworkManager = .shared) async throws -> Data? {
        let box = calculateBoundingBox(center: location, radiusInMeters: radius)
        let query =
            """
            [out:json][timeout:25][bbox:\(box.minLatitude),\(box.minLongitude),\(box.maxLatitude),\(box.maxLongitude)];
            (
                node["shop"="funeral_directors"](around:\(radius),\(location.latitude),\(location.longitude));
                way["shop"="funeral_directors"](around:\(radius),\(location.latitude),\(location.longitude));
                node["amenity"="funeral_hall"](around:\(radius),\(location.latitude),\(location.longitude));
                way["amenity"="funeral_hall"](around:\(radius),\(location.latitude),\(location.longitude));
            )->.funeral_homes;
            .funeral_homes out center tags qt;
            """
        guard
            let urlString = "https://overpass-api.de/api/interpreter?data=\(query)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        else {
            return nil
        }
        trace.debug("Fetching nearby funeral directors...")
        let result = await networkManager.performDataRequest(urlString: urlString, priority: .background)
        switch result {
            case .success(let data):
                trace.debug("Fetched nearby funeral directors.")
                return data
            case .failure(let error):
                trace.error("Failed to fetch nearby funeral directors: \(error.localizedDescription)")
                return nil
        }
    }

    //[out:json][timeout:25][bbox:52.47099,13.36611,52.56901,13.44389];
    //(
    //    way["landuse"="cemetery"](around:5000, 52.5199, 13.3652);
    //    way["amenity"="grave_yard"](around:5000, 52.5199, 13.3652);
    //)->.graveyards;
    //.graveyards out center tags qt;
    public static func fetchCemeteries(location: Location, radius: Double, networkManager: NetworkManager = .shared) async throws -> Data? {
        let box = calculateBoundingBox(center: location, radiusInMeters: radius)
        let query =
            """
            [out:json][timeout:25][bbox:\(box.minLatitude),\(box.minLongitude),\(box.maxLatitude),\(box.maxLongitude)];
            (
                way["landuse"="cemetery"](around:\(radius),\(location.latitude),\(location.longitude));
                way["amenity"="grave_yard"](around:\(radius),\(location.latitude),\(location.longitude));
            )->.graveyards;
            .graveyards out center tags qt;
            """
        guard
            let urlString = "https://overpass-api.de/api/interpreter?data=\(query)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        else {
            return nil
        }
        trace.debug("Fetching nearby cemeteries...")
        let result = await networkManager.performDataRequest(urlString: urlString, priority: .background)
        switch result {
            case .success(let data):
                trace.debug("Fetched nearby cemeteries.")
                return data
            case .failure(let error):
                trace.error("Failed to fetch nearby cemeteries: \(error.localizedDescription)")
                return nil
        }
    }
}
