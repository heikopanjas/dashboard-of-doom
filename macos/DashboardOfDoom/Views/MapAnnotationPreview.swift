#if os(macOS) && DEBUG
import DoomKitLocation
import DoomKitProcess
import MapKit
import SwiftUI

/// No live services, location tracking, timers, or preference writes in these fixtures.
private struct MapAnnotationPreview: View {
    private let annotations: [MapAnnotationSnapshot]
    private let showsPointsOfInterest: Bool
    private let places: [PointOfInterest]
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 52.52, longitude: 13.405), span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.12))
    )

    var body: some View {
        CollisionMapView(position: self.$position, annotations: self.annotations, showsPointsOfInterest: self.showsPointsOfInterest, pointsOfInterest: self.places)
    }

    init(coincident: Bool, separated: Bool = false, placeCount: Int = 0, showsPointsOfInterest: Bool = false) {
        self.showsPointsOfInterest = showsPointsOfInterest
        self.places = (0 ..< placeCount).map { index -> PointOfInterest in
            let latitude = 52.49 + Double((index * 37) % 1000) * 0.00006
            let longitude = 13.345 + Double((index * 61) % 1000) * 0.00012
            let location = Location(latitude: latitude, longitude: longitude)
            return PointOfInterest(
                category: PointOfInterestCategory.allCases[index % 5], elementType: "node",
                elementID: Int64(index), name: nil, location: location)
        }
        let selectors: [ProcessSelector] = [
            .weather(.temperature), .covid(.incidence), .particle(.pm10), .water(.level), .radiation(.total), .survey(.fascists)
        ]
        let icons = ["thermometer", "cross.case", "aqi.medium", "water.waves", "atom", "chart.bar"]
        let values = ["22.0 °C", "Ω 12.3", "18 µg/m³", "2.73 m", "0.08 µSv/h", "ν 20.0 %"]
        self.annotations = selectors.enumerated().map { index, selector in
            let presenter = ProcessPresenter()
            let location =
                separated == true
                ? Location(latitude: 52.505 + Double(index / 3) * 0.03, longitude: 13.365 + Double(index % 3) * 0.04)
                : Location(latitude: 52.52 + (coincident == true ? 0 : Double(index) * 0.001), longitude: 13.405)
            let sensor = ProcessSensor(
                name: "Fixture", location: location,
                placemark: "Berlin", customData: ["icon": icons[index]], measurements: [:], timestamp: nil)
            presenter.replace(readings: [ProcessReading(sensor: sensor, faceplate: [selector: values[index]])])
            return MapAnnotationSnapshot(id: String(index), presenter: presenter, selector: selector, user: index == 0)
        }
    }
}

#Preview("Two thousand places with environmental labels") {
    MapAnnotationPreview(coincident: false, separated: true, placeCount: 2000, showsPointsOfInterest: true).frame(width: 600, height: 400)
}

#Preview("Ten thousand places with environmental labels") {
    MapAnnotationPreview(coincident: false, separated: true, placeCount: 10000, showsPointsOfInterest: true).frame(width: 600, height: 400)
}

#Preview("Dense POIs, dark appearance") {
    MapAnnotationPreview(coincident: false, separated: true, placeCount: 2000, showsPointsOfInterest: true)
        .frame(width: 600, height: 400).preferredColorScheme(.dark)
}

#Preview("POIs enabled, loading or empty") {
    MapAnnotationPreview(coincident: false, separated: true, showsPointsOfInterest: true).frame(width: 600, height: 400)
}

#Preview("Separated locations without connectors") {
    MapAnnotationPreview(coincident: false, separated: true).frame(width: 600, height: 400)
}

#Preview("Six coincident locations") {
    MapAnnotationPreview(coincident: true).frame(width: 600, height: 400)
}

#Preview("Dense cluster, narrow map") {
    MapAnnotationPreview(coincident: false).frame(width: 360, height: 300)
}

#Preview("Undersized viewport") {
    MapAnnotationPreview(coincident: true).frame(width: 200, height: 120)
}
#endif
