import AppKit
import DoomKitLocation
import DoomKitProcess
import DoomKitTools
import SwiftUI
import Testing

@MainActor
struct MapLabelRenderingTests {
    @Test func densePOILabelsInBothAppearances() throws {
        let app = NSApplication.shared
        let oldAppearance = app.appearance
        defer { app.appearance = oldAppearance }
        let selectors: [ProcessSelector] = [
            .weather(.temperature), .covid(.incidence), .particle(.pm10), .water(.level), .radiation(.total), .survey(.fascists)
        ]
        let values = ["22.0 °C", "Ω 12.3", "18 µg/m³", "2.73 m", "0.08 µSv/h", "ν 20.0 %"]
        let icons = ["thermometer", "cross.case", "aqi.medium", "water.waves", "atom", "chart.bar"]
        let annotations = selectors.enumerated().map { index, selector in
            let presenter = ProcessPresenter()
            let sensor = ProcessSensor(
                name: "Fixture", location: Location(latitude: 52.52, longitude: 13.4),
                placemark: "Berlin", customData: ["icon": icons[index]], measurements: [:], timestamp: nil)
            presenter.replace(readings: [ProcessReading(sensor: sensor, faceplate: [selector: values[index]])])
            return MapAnnotationSnapshot(id: String(index), presenter: presenter, selector: selector)
        }
        let items: [AnnotationLayout.Item] = selectors.indices.map { index in
            let x = CGFloat(60 + (index % 3) * 190)
            let y = CGFloat(85 + (index / 3) * 180)
            let point = CGPoint(x: x, y: y)
            return AnnotationLayout.Item(
                id: String(index), point: point,
                marker: CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10), size: AnnotationLayout.labelSize)
        }
        let placements = AnnotationLayout.place(items, in: CGRect(x: 0, y: 0, width: 600, height: 400)).placements
        var symbols: [PointOfInterestProjection.Symbol] = []
        for index in 0 ..< 2000 {
            let x = CGFloat((index * 37) % 600)
            let y = CGFloat((index * 61) % 400)
            let category = PointOfInterestCategory.allCases[index % 5]
            symbols.append(PointOfInterestProjection.Symbol(id: String(index), category: category, point: CGPoint(x: x, y: y)))
        }
        #expect(MapAnnotationLabel(selector: selectors[0], icon: icons[0], faceplate: values[0]).backgroundOpacity == 0.5)
        for dark in [false, true] {
            app.appearance = NSAppearance(named: dark == true ? .darkAqua : .aqua)
            for enabled in [false, true] {
                let view = ZStack {
                    (dark == true ? Color(white: 0.12) : Color(white: 0.94))
                    PointOfInterestOverlay(symbols: enabled == true ? symbols : [], markers: items.map(\.marker))
                    MapAnnotationOverlay(annotations: annotations, items: items, placements: placements, showsPointsOfInterest: enabled)
                }
                .frame(width: 600, height: 400)
                .environment(\.colorScheme, dark == true ? .dark : .light)
                let renderer = ImageRenderer(content: view)
                renderer.scale = 2
                let image = try #require(renderer.cgImage)
                #expect(image.width == 1200)
                #expect(image.height == 800)
                let data = try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
                let path = "/tmp/doom-labels-\(dark == true ? "dark" : "light")-\(enabled == true ? "pois" : "plain").png"
                try data.write(to: URL(fileURLWithPath: path))
            }
        }
    }
}
