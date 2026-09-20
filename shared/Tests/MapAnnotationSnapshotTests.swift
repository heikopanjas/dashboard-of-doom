import DoomKitLocation
import DoomKitProcess
import Foundation
import SwiftUI
import Testing

@MainActor
@Suite struct MapAnnotationSnapshotTests {
    @Test func aSnapshotFromValuesCarriesThemAndIsNotTheUser() {
        let location = Location(latitude: 52.5, longitude: 13.4)
        let snapshot = MapAnnotationSnapshot(id: "water-a", location: location, selector: .water(.level), icon: "water.waves", faceplate: "H: 2.73m")
        #expect(snapshot.id == "water-a")
        #expect(snapshot.location == location)
        #expect(snapshot.selector == .water(.level))
        #expect(snapshot.icon == "water.waves")
        #expect(snapshot.faceplate == "H: 2.73m")
        #expect(snapshot.showsLabel == true)
        #expect(snapshot.user == false)
        #expect(MapAnnotationSnapshot(id: "a", location: location, selector: .water(.level), icon: "x", faceplate: "y", showsLabel: false).showsLabel == false)
    }

    @Test func aSnapshotUsesItsSelectorColorUnlessItHasOneOfItsOwn() {
        let location = Location(latitude: 52.5, longitude: 13.4)
        let plain = MapAnnotationSnapshot(id: "a", location: location, selector: .radiation(.total), icon: "atom", faceplate: "x")
        #expect(plain.color == nil)
        #expect(plain.displayColor == Color.radiation)
        let own = MapAnnotationSnapshot(id: "b", location: location, selector: .radiation(.total), icon: "atom", faceplate: "x", color: .pink)
        #expect(own.color == Color.pink)
        #expect(own.displayColor == Color.pink)
    }

    @Test func theSnapshotFromAPresenterStillReadsItsNearestSensor() {
        let presenter = ProcessPresenter()
        let sensor = ProcessSensor(
            name: "Station", location: Location(latitude: 52.6, longitude: 13.5), placemark: nil, customData: ["icon": "atom"], measurements: [:],
            timestamp: nil)
        presenter.replace(readings: [ProcessReading(sensor: sensor, faceplate: [.radiation(.total): "Γ: 0.1"])])
        let snapshot = MapAnnotationSnapshot(id: "radiation", presenter: presenter, selector: .radiation(.total))
        #expect(snapshot.location == Location(latitude: 52.6, longitude: 13.5))
        #expect(snapshot.icon == "atom")
        #expect(snapshot.faceplate == "Γ: 0.1")
        // The home map builds its snapshots this way, and keeps the color of the selector.
        #expect(snapshot.color == nil)
        #expect(snapshot.displayColor == Color.radiation)
    }
}
