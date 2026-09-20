import CoreLocation

@MainActor
final class NativeGeocoder {
    private let geocoder = CLGeocoder()

    static func lookup(_ location: Location) async throws -> GeocodedPlace? {
        let service = Self()
        return try await service.lookup(location)
    }

    private func lookup(_ location: Location) async throws -> GeocodedPlace? {
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            let placemarks = try await self.geocoder.reverseGeocodeLocation(
                CLLocation(latitude: location.latitude, longitude: location.longitude))
            try Task.checkCancellation()
            guard let place = placemarks.first else { return nil }
            return GeocodedPlace(
                name: place.name, postalCode: place.postalCode, locality: place.locality,
                subLocality: place.subLocality, administrativeArea: place.administrativeArea,
                subAdministrativeArea: place.subAdministrativeArea)
        } onCancel: {
            Task { @MainActor in self.geocoder.cancelGeocode() }
        }
    }
}
