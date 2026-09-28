import DoomKitLocation
import Foundation
import Observation

/// The place picked in the simulation window, and whether it can be simulated: only places in Germany, since every source the app reads
/// covers Germany alone.
@MainActor @Observable final class SimulationSelection {
    enum Status: Equatable {
        /// Nothing picked yet.
        case none
        /// Waiting for the geocoder.
        case checking
        /// In Germany, with the address to show under the map.
        case inGermany(address: String)
        /// Outside Germany, or a place the geocoder could not name.
        case outside
    }

    /// Germany's bounding box, a quick check before the geocoder is asked. It also holds bits of every neighbour, so the geocoder's
    /// country code decides.
    static let latitudes: ClosedRange<Double> = 47.2 ... 55.1
    static let longitudes: ClosedRange<Double> = 5.8 ... 15.1

    private(set) var location: Location?
    private(set) var status: Status = .none
    /// A short name for the place, its town where the geocoder gives one, else its address: what the iOS SIM capsule shows.
    private(set) var placeName: String?
    @ObservationIgnored private let geocoding: GeocodingService
    @ObservationIgnored private var generation = UUID()

    init(geocoding: GeocodingService = GeocodingService()) {
        self.geocoding = geocoding
    }

    var canStart: Bool {
        if case .inGermany = self.status {
            return true
        }
        return false
    }

    /// Picks `location` and checks it. A later pick wins over an earlier one whose check is still running.
    func select(_ location: Location) async {
        let generation = UUID()
        self.generation = generation
        self.location = location
        self.placeName = nil
        guard Self.latitudes.contains(location.latitude), Self.longitudes.contains(location.longitude) else {
            self.status = .outside
            return
        }
        self.status = .checking
        let place = try? await self.geocoding.place(for: location)
        guard self.generation == generation else { return }
        if let place, place.isoCountryCode == "DE" {
            let address = place.address(full: true)
            let shown = address.isEmpty ? String(format: "%.4f, %.4f", location.latitude, location.longitude) : address
            self.status = .inGermany(address: shown)
            self.placeName = place.locality ?? shown
        }
        else {
            self.status = .outside
        }
    }
}
