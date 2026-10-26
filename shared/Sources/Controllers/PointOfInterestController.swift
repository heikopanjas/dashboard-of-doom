import DoomKitLocation
import DoomKitServices
import Foundation

struct PointOfInterestController: Sendable {
    // This nonisolated async boundary keeps decoding off the main actor in Swift 5 mode.
    func fetch(category: PointOfInterestCategory, location: Location) async throws -> [PointOfInterest] {
        let radius = 6666.67
        let data: Data?
        switch category {
            case .pharmacies: data = try await PointOfInterestService.fetchPharmacies(location: location, radius: radius)
            case .hospitals: data = try await PointOfInterestService.fetchHospitals(location: location, radius: radius)
            case .stores: data = try await PointOfInterestService.fetchLiquorStores(location: location, radius: radius)
            case .funeralDirectors: data = try await PointOfInterestService.fetchFuneralDirectors(location: location, radius: radius)
            case .cemeteries: data = try await PointOfInterestService.fetchCemeteries(location: location, radius: radius)
        }
        try Task.checkCancellation()
        guard let data else { throw URLError(.badServerResponse) }
        return try Self.decode(data, category: category)
    }

    static func decode(_ data: Data, category: PointOfInterestCategory) throws -> [PointOfInterest] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let elements = json["elements"] as? [[String: Any]]
        else { throw URLError(.cannotParseResponse) }
        var seen = Set<String>()
        var points: [PointOfInterest] = []
        for element in elements {
            guard let type = element["type"] as? String, type == "node" || type == "way",
                let id = element["id"] as? Int64
            else { continue }
            let coordinates = type == "node" ? element : element["center"] as? [String: Any] ?? [:]
            guard let latitude = coordinates["lat"] as? Double, let longitude = coordinates["lon"] as? Double,
                latitude.isFinite, longitude.isFinite, (-90 ... 90).contains(latitude), (-180 ... 180).contains(longitude)
            else { continue }
            let tags = element["tags"] as? [String: Any]
            let point = PointOfInterest(
                category: category, elementType: type, elementID: id, name: tags?["name"] as? String,
                location: Location(latitude: latitude, longitude: longitude))
            if seen.insert(point.id).inserted == true { points.append(point) }
        }
        return points.sorted { $0.id < $1.id }
    }
}
