import DoomKitLocation
import DoomKitProcess
import Foundation
import Testing

@Suite struct SensorHeaderViewTests {
    private func reading(name: String = "Spree", placemark: String? = nil, customData: [String: Any]? = nil, distance: Double? = nil) -> ProcessReading {
        let sensor = ProcessSensor(
            name: name, location: Location(latitude: 52.5, longitude: 13.4), placemark: placemark, customData: customData, measurements: [:],
            timestamp: Date(timeIntervalSince1970: 0), sourceID: "id", distance: distance)
        return ProcessReading(sensor: sensor)
    }

    @Test(arguments: [
        ("BERLIN-MÜHLENDAMM UP", "Berlin-Mühlendamm UP"),
        ("BERLIN-CHARLOTTENBURG OP", "Berlin-Charlottenburg OP"),
        ("ST. PAULI", "St. Pauli"),
        ("LANDSBERG (WARTHE)", "Landsberg (Warthe)"),
        ("KÖPENICK", "Köpenick"),
        ("Berlin-Mitte", "Berlin-Mitte"),
        ("Freiburg im Breisgau", "Freiburg im Breisgau"),
        ("", "")
    ])
    func displayNameCapitalizesCapitalsOnly(input: String, expected: String) {
        #expect(SensorHeaderView.displayName(input) == expected)
    }

    @Test func nearestShowsItsAddress() {
        #expect(SensorHeaderView.title(for: self.reading(placemark: "Alexanderplatz, Berlin"), isNearest: true) == "Alexanderplatz, Berlin")
        #expect(SensorHeaderView.title(for: self.reading(placemark: nil), isNearest: true) == "<Unknown>")
    }

    @Test func otherSensorsShowTheStationTheyAreNamedAfter() {
        // A level sensor is named after its gauge, like every other source, and PEGELONLINE writes those in capitals. The waterway it
        // carries in customData is the chart title, never the header.
        let gauge = self.reading(name: "BERLIN-KÖPENICK", customData: ["waterway": "Spree"])
        #expect(SensorHeaderView.title(for: gauge, isNearest: false) == "Berlin-Köpenick")
        #expect(SensorHeaderView.title(for: self.reading(name: "Berlin-Marzahn"), isNearest: false) == "Berlin-Marzahn")
        // An address, when there is one, is not used for the others.
        #expect(SensorHeaderView.title(for: self.reading(name: "Teltow", placemark: "Somewhere"), isNearest: false) == "Teltow")
    }

    @Test func subtitleAddsTheDistanceForOtherSensorsOnly() {
        let far = self.reading(distance: 7_200)
        #expect(SensorHeaderView.subtitle(for: far, isNearest: false).hasPrefix("7.2 km away · Last update: ") == true)
        #expect(SensorHeaderView.subtitle(for: self.reading(distance: 640), isNearest: false).hasPrefix("640 m away · ") == true)
        #expect(SensorHeaderView.subtitle(for: far, isNearest: true).hasPrefix("Last update: ") == true)
        #expect(SensorHeaderView.subtitle(for: self.reading(distance: nil), isNearest: false).hasPrefix("Last update: ") == true)
    }
}
