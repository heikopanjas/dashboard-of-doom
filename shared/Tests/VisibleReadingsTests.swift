import DoomKitLocation
import DoomKitProcess
import Foundation
import Testing

@MainActor
@Suite struct VisibleReadingsTests {
    private func presenter(sensors count: Int) -> ProcessPresenter {
        let presenter = ProcessPresenter()
        let readings = (0 ..< count).map { index in
            let sensor = ProcessSensor(
                name: "Station \(index)", location: Location(latitude: 52.5 + Double(index) * 0.01, longitude: 13.4), placemark: nil,
                customData: nil, measurements: [:], timestamp: nil, sourceID: "id-\(index)")
            return ProcessReading(sensor: sensor)
        }
        presenter.replace(readings: readings)
        return presenter
    }

    @Test func withTheSwitchOffOnlyTheNearestReadingIsListed() {
        let presenter = self.presenter(sensors: 3)
        #expect(presenter.visibleReadings(multiSensor: false).map { $0.id } == ["id-0"])
        // The presenter still holds all of them until a refresh replaces them, which is why the view trims.
        #expect(presenter.readings.count == 3)
    }

    @Test func withTheSwitchOnAllReadingsAreListedNearestFirst() {
        #expect(self.presenter(sensors: 3).visibleReadings(multiSensor: true).map { $0.id } == ["id-0", "id-1", "id-2"])
    }

    @Test func fewerReadingsThanTheCapAreAllListed() {
        #expect(self.presenter(sensors: 1).visibleReadings(multiSensor: false).map { $0.id } == ["id-0"])
        #expect(self.presenter(sensors: 1).visibleReadings(multiSensor: true).map { $0.id } == ["id-0"])
    }

    @Test(arguments: [false, true])
    func noReadingsStaysEmpty(multiSensor: Bool) {
        #expect(self.presenter(sensors: 0).visibleReadings(multiSensor: multiSensor).isEmpty == true)
    }
}
