import CoreLocation

public struct GeocodingService: Sendable {
    private let lookup: @Sendable (Location) async throws -> GeocodedPlace?

    public init(lookup: @escaping @Sendable (Location) async throws -> GeocodedPlace?) {
        self.lookup = lookup
    }

    public init() {
        self.lookup = { location in
            return try await NativeGeocoder.lookup(location)
        }
    }

    public func address(for location: Location, full: Bool = true) async throws -> String? {
        let place = try await self.lookup(location)
        try Task.checkCancellation()
        return place?.address(full: full)
    }

    public func constituency(for location: Location) async throws -> String? {
        let place = try await self.lookup(location)
        try Task.checkCancellation()
        return place?.constituency
    }

    public static func reverseGeocodeLocation(location: Location, fullAddress: Bool = true) async -> String? {
        return try? await Self().address(for: location, full: fullAddress)
    }

    public static func reverseGeocodeLocation(latitude: Double, longitude: Double, fullAddress: Bool = true) async -> String? {
        return await Self.reverseGeocodeLocation(location: Location(latitude: latitude, longitude: longitude), fullAddress: fullAddress)
    }

    public static func fetchConstituency(location: Location) async throws -> String? {
        return try await Self().constituency(for: location)
    }
}
