import DoomKitLocation
import Foundation
import Testing

@MainActor @Suite struct SimulationSelectionTests {
    private final class Lookups: @unchecked Sendable {
        private let lock = NSLock()
        private var count = 0

        var value: Int {
            self.lock.lock()
            defer { self.lock.unlock() }
            return self.count
        }

        func record() {
            self.lock.lock()
            self.count += 1
            self.lock.unlock()
        }
    }

    private func selection(country: String?, lookups: Lookups = Lookups()) -> SimulationSelection {
        return SimulationSelection(
            geocoding: GeocodingService { _ in
                lookups.record()
                return GeocodedPlace(name: "Augustusbrücke", postalCode: "01067", locality: "Dresden", isoCountryCode: country)
            })
    }

    @Test func aPlaceInGermanyCanBeSimulated() async {
        let selection = self.selection(country: "DE")
        #expect(selection.canStart == false)
        await selection.select(Location(latitude: 51.054, longitude: 13.738))
        #expect(selection.status == .inGermany(address: "Augustusbrücke, 01067 Dresden"))
        #expect(selection.canStart == true)
        #expect(selection.location == Location(latitude: 51.054, longitude: 13.738))
        // The capsule's short name is the town.
        #expect(selection.placeName == "Dresden")
    }

    @Test func withoutATownTheNameIsTheAddress() async {
        let selection = SimulationSelection(geocoding: GeocodingService { _ in
            return GeocodedPlace(name: "Hallig Hooge", isoCountryCode: "DE")
        })
        await selection.select(Location(latitude: 54.57, longitude: 8.55))
        #expect(selection.placeName == "Hallig Hooge")
        // A pick outside Germany has no name to show.
        await selection.select(Location(latitude: 48.86, longitude: 2.35))
        #expect(selection.placeName == nil)
    }

    @Test func aNeighbourInsideTheBoxCannot() async {
        // Enschede lies inside Germany's bounding box, but in the Netherlands.
        let selection = self.selection(country: "NL")
        await selection.select(Location(latitude: 52.22, longitude: 6.89))
        #expect(selection.status == .outside)
        #expect(selection.canStart == false)
    }

    @Test func outsideTheBoxTheGeocoderIsNotAsked() async {
        let lookups = Lookups()
        let selection = self.selection(country: "DE", lookups: lookups)
        await selection.select(Location(latitude: 48.86, longitude: 2.35))
        #expect(selection.status == .outside)
        #expect(lookups.value == 0)
    }

    @Test func aPlaceTheGeocoderCannotNameCannotBeSimulated() async {
        let selection = SimulationSelection(geocoding: GeocodingService { _ in return nil })
        await selection.select(Location(latitude: 54.5, longitude: 7.5))
        #expect(selection.status == .outside)
    }
}
