import DoomKitLocation
import MapKit
import SwiftUI
import Testing

/// The map the Environment, Particles and Energy tabs share, and the reader's own marker on it. The three tabs build their sensor
/// annotations themselves and are tested separately; this is what they have in common.
@MainActor
@Suite struct SensorMapViewTests {
    @Test func theUserMarkerIsABlackHaloedDotWithoutALabel() {
        let location = Location(latitude: 52.51889, longitude: 13.36528)
        let marker = SensorMapView.userAnnotation(at: location)
        #expect(marker.location == location)
        // The halo the home map gives the user, so black stays visible over dark terrain.
        #expect(marker.user == true)
        // A coordinate has no reading, so there is nothing to label and no connector to draw.
        #expect(marker.showsLabel == false)
        #expect(marker.displayColor == Color.user)
        #expect(marker.displayColor != Color.faceplate(selector: marker.selector))
    }

    @Test func theUserMarkerSharesNoIdWithASensor() {
        let location = Location(latitude: 52.5, longitude: 13.4)
        // A duplicate id silently drops a label, so the marker must not collide with the ids the four tabs use.
        let ids = ["radiation-", "water-", "particles-", "fuel-", "covid"]
        #expect(ids.contains(where: { SensorMapView.userAnnotation(at: location).id.hasPrefix($0) }) == false)
    }

    @Test func theReaderIsInsideTheCamera() throws {
        let sensor = Location(latitude: 52.6, longitude: 13.5)
        let reader = Location(latitude: 52.51889, longitude: 13.36528)
        let rect = try #require(SensorMapView.rect(for: [sensor, reader]))
        #expect(rect.contains(MKMapPoint(sensor.coordinate)) == true)
        #expect(rect.contains(MKMapPoint(reader.coordinate)) == true)
    }

    @Test func tighterPaddingFramesTheSamePointsMoreClosely() throws {
        let north = Location(latitude: 52.6, longitude: 13.4)
        let south = Location(latitude: 52.4, longitude: 13.5)
        let loose = try #require(SensorMapView.rect(for: [north, south]))
        let snug = try #require(SensorMapView.rect(for: [north, south], padding: 1.15))
        // The COVID map passes a smaller factor: a district fills its own frame and needs room for one label, not six.
        #expect(snug.size.height < loose.size.height)
        #expect(snug.contains(MKMapPoint(north.coordinate)) == true)
        #expect(snug.contains(MKMapPoint(south.coordinate)) == true)
        // The default is unchanged, which is what keeps the other three maps framed as they were.
        let explicit = try #require(SensorMapView.rect(for: [north, south], padding: 2))
        #expect(loose.size.height == explicit.size.height)
    }

    @Test func aFarReaderWidensTheCamera() throws {
        let sensor = Location(latitude: 52.5, longitude: 13.4)
        let far = Location(latitude: 53.5, longitude: 13.4)
        let sensorsOnly = try #require(SensorMapView.rect(for: [sensor]))
        let withReader = try #require(SensorMapView.rect(for: [sensor, far]))
        // The accepted cost of always showing the marker: a distant sensor, or a distant reader, zooms the camera out until both fit.
        #expect(withReader.size.height > sensorsOnly.size.height)
        #expect(withReader.contains(MKMapPoint(far.coordinate)) == true)
    }
}
