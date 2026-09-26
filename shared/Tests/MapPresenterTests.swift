import DoomKitLocation
import Foundation
import MapKit
import Testing

/// `MapPresenter.shared` is one object for the whole process and other suites add entries to it at the same time, so these tests look only
/// at their own entries and at whether the rectangle matches the visible locations, never at absolute coordinates.
@MainActor
@Suite struct MapPresenterTests {
    private static let berlin = Location(latitude: 52.52, longitude: 13.40)
    private static let munich = Location(latitude: 48.14, longitude: 11.58)
    private static let hamburg = Location(latitude: 53.55, longitude: 9.99)

    private var presenter: MapPresenter { return MapPresenter.shared }

    @Test func aHiddenSourceStaysOutOfTheCamera() {
        let id = UUID()
        defer { self.presenter.updateRegion(remove: id) }
        self.presenter.updateRegion(for: id, with: Self.berlin, isVisible: { false })
        #expect(self.presenter.visibleRegion[id] == nil)
    }

    @Test func aSettingsChangeReEvaluatesEveryCheckWithoutARefresh() async {
        // The switch is changed while nothing refreshes, as when a source is switched off in Settings with the home map off screen.
        let id = UUID()
        defer { self.presenter.updateRegion(remove: id) }
        var visible = true
        self.presenter.updateRegion(for: id, with: Self.berlin, isVisible: { visible })
        #expect(self.presenter.visibleRegion[id] == Self.berlin)
        visible = false
        NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: nil)
        for _ in 0 ..< 100 where self.presenter.visibleRegion[id] != nil {
            try? await Task.sleep(for: .milliseconds(10))
        }
        #expect(self.presenter.visibleRegion[id] == nil)
        visible = true
        self.presenter.refreshRegion()
        #expect(self.presenter.visibleRegion[id] == Self.berlin)
    }

    @Test func aMovedSensorLeavesNothingBehind() {
        let id = UUID()
        defer { self.presenter.updateRegion(remove: id) }
        self.presenter.updateRegion(for: id, with: Self.hamburg)
        self.presenter.updateRegion(for: id, with: Self.munich)
        #expect(self.presenter.visibleRegion[id] == Self.munich)
        // The rectangle is rebuilt from the visible locations, not added to, so the old position does not stretch it.
        #expect(MKMapRectEqualToRect(self.presenter.visibleRectangle, MapPresenter.rectangle(for: Array(self.presenter.visibleRegion.values))) == true)
    }

    @Test func anUpdateWithoutACheckKeepsTheOneItHas() {
        // The iOS map moves the weather marker with the reader without knowing whether weather counts.
        let id = UUID()
        defer { self.presenter.updateRegion(remove: id) }
        self.presenter.updateRegion(for: id, with: Self.berlin, isVisible: { false })
        self.presenter.updateRegion(for: id, with: Self.munich)
        #expect(self.presenter.visibleRegion[id] == nil)
    }

    @Test func theRectangleOfOneLocationDoesNotReachAnother() {
        let rectangle = MapPresenter.rectangle(for: [Self.munich])
        #expect(rectangle.contains(MKMapPoint(Self.munich.coordinate)) == true)
        #expect(rectangle.contains(MKMapPoint(Self.hamburg.coordinate)) == false)
        #expect(MapPresenter.rectangle(for: []).isNull == true)
    }
}
