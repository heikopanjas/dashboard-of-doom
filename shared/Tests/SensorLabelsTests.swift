import DoomKitLocation
import DoomKitProcess
import Foundation
import Testing

@Suite struct SensorLabelsTests {
    private func reading(name: String, placemark: String? = nil, distance: Double? = nil) -> ProcessReading {
        let sensor = ProcessSensor(
            name: name, location: Location(latitude: 52.5, longitude: 13.4), placemark: placemark, customData: nil, measurements: [:],
            timestamp: Date(timeIntervalSince1970: 0), sourceID: "id", distance: distance)
        return ProcessReading(sensor: sensor)
    }

    @Test func theNearestShowsItsAddressTheOthersTheirStation() {
        #expect(SensorLabels.title(for: self.reading(name: "X", placemark: "Tiergarten"), isNearest: true) == "Tiergarten")
        #expect(SensorLabels.title(for: self.reading(name: "BERLIN-MÜHLENDAMM UP", placemark: "Mitte"), isNearest: false) == "Berlin-Mühlendamm UP")
    }

    @Test func theOthersSayHowFarAway() {
        let far = SensorLabels.subtitle(for: self.reading(name: "X", distance: 2400), isNearest: false)
        #expect(far.hasPrefix("2.4 km away · Last update: ") == true)
        // The nearest has an address, so no distance.
        #expect(SensorLabels.subtitle(for: self.reading(name: "X", distance: 2400), isNearest: true).hasPrefix("Last update: ") == true)
    }

    @Test func distancesUnderAKilometreAreInMetres() {
        #expect(SensorLabels.distanceString(800) == "800 m")
        #expect(SensorLabels.distanceString(1000) == "1.0 km")
    }
}
