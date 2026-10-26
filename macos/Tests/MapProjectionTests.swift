import CoreLocation
import MapKit
import Testing

@Suite struct MapProjectionTests {
    private static let berlin = CLLocationCoordinate2D(latitude: 52.52, longitude: 13.40)

    @Test func theCornersOfTheVisibleRectangleAreTheCornersOfTheView() throws {
        let center = MKMapPoint(Self.berlin)
        let rect = MKMapRect(x: center.x - 5_000, y: center.y - 2_500, width: 10_000, height: 5_000)
        let size = CGSize(width: 800, height: 400)
        let topLeft = try #require(MapProjection.point(for: MKMapPoint(x: rect.minX, y: rect.minY).coordinate, in: rect, size: size))
        let bottomRight = try #require(MapProjection.point(for: MKMapPoint(x: rect.maxX, y: rect.maxY).coordinate, in: rect, size: size))
        #expect(abs(topLeft.x) < 0.001 && abs(topLeft.y) < 0.001)
        #expect(abs(bottomRight.x - 800) < 0.001 && abs(bottomRight.y - 400) < 0.001)
        // The centre of the rectangle is the centre of the view, wherever the view is hosted.
        let middle = try #require(MapProjection.point(for: Self.berlin, in: rect, size: size))
        #expect(abs(middle.x - 400) < 0.001 && abs(middle.y - 200) < 0.001)
    }

    @Test func northIsUp() throws {
        let center = MKMapPoint(Self.berlin)
        let rect = MKMapRect(x: center.x - 50_000, y: center.y - 50_000, width: 100_000, height: 100_000)
        let size = CGSize(width: 500, height: 500)
        let north = try #require(MapProjection.point(for: CLLocationCoordinate2D(latitude: 52.60, longitude: 13.40), in: rect, size: size))
        let south = try #require(MapProjection.point(for: CLLocationCoordinate2D(latitude: 52.44, longitude: 13.40), in: rect, size: size))
        #expect(north.y < south.y)
    }

    @Test func aClickedPointTurnsBackIntoItsCoordinate() throws {
        let center = MKMapPoint(Self.berlin)
        let rect = MKMapRect(x: center.x - 80_000, y: center.y - 60_000, width: 160_000, height: 120_000)
        let size = CGSize(width: 640, height: 480)
        for point in [CGPoint(x: 0, y: 0), CGPoint(x: 320, y: 240), CGPoint(x: 640, y: 480), CGPoint(x: 97, y: 411)] {
            let coordinate = try #require(MapProjection.coordinate(for: point, in: rect, size: size))
            let back = try #require(MapProjection.point(for: coordinate, in: rect, size: size))
            #expect(abs(back.x - point.x) < 0.001 && abs(back.y - point.y) < 0.001)
        }
        let middle = try #require(MapProjection.coordinate(for: CGPoint(x: 320, y: 240), in: rect, size: size))
        #expect(abs(middle.latitude - Self.berlin.latitude) < 0.000_001 && abs(middle.longitude - Self.berlin.longitude) < 0.000_001)
        #expect(MapProjection.coordinate(for: .zero, in: .null, size: size) == nil)
    }

    @Test func anEmptyRectangleOrViewProjectsNothing() {
        #expect(MapProjection.point(for: Self.berlin, in: .null, size: CGSize(width: 100, height: 100)) == nil)
        #expect(MapProjection.point(for: Self.berlin, in: MKMapRect(x: 0, y: 0, width: 10, height: 10), size: .zero) == nil)
    }
}
