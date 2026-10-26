import DoomKitLocation
import DoomKitTools
import MapKit
import SwiftUI

struct CollisionMapView: View {
    @Binding var position: MapCameraPosition
    let annotations: [MapAnnotationSnapshot]
    var showsPointsOfInterest = false
    var pointsOfInterest: [PointOfInterest] = []
    /// Areas to shade, as rings of coordinates, such as the COVID district. They are map content and need no projection, so they take no
    /// part in label placement.
    var polygons: [[Location]] = []
    /// The color of those areas. It defaults to the only source that has one today, so the next one can pass its own rather than change
    /// this view.
    var polygonColor: Color = .covid
    @State private var poiProjection = PointOfInterestProjection(symbols: [], projectedCount: 0)

    private struct POITrigger: Equatable {
        let inputs: [PointOfInterestProjection.Input]
        let size: CGSize
    }
    @State private var layout = LayoutState()
    /// The map's visible rectangle as of its last camera change. Labels and place markers are projected from it (`MapProjection`), not
    /// through `MapProxy`, whose conversion was off inside the macOS popup.
    @State private var visibleRect: MKMapRect?

    private struct Request: Equatable {
        let items: [AnnotationLayout.Item]
        let viewport: CGRect
    }

    private struct GeometryInput: Equatable {
        let id: String
        let latitude: Double
        let longitude: Double
        let user: Bool
        let size: CGSize?
    }

    private struct Trigger: Equatable {
        let annotations: [GeometryInput]
        let size: CGSize
    }

    private struct LayoutState {
        var request: Request?
        var placements: [AnnotationLayout.Placement] = []
    }

    var body: some View {
        GeometryReader { geometry in
            Group {
                let poiTrigger = POITrigger(inputs: self.pointsOfInterest.map(PointOfInterestProjection.Input.init), size: geometry.size)
                let trigger = Trigger(
                    annotations: self.annotations.map {
                        GeometryInput(
                            id: $0.id, latitude: $0.location.latitude, longitude: $0.location.longitude,
                            user: $0.user, size: $0.showsLabel == true ? MapAnnotationLabel.size : nil)
                    }, size: geometry.size)
                Map(position: self.$position, interactionModes: []) {
                    // First, so the shading stays under the dots. A ring is not Identifiable, hence the offset key.
                    ForEach(Array(self.polygons.enumerated()), id: \.offset) { _, ring in
                        MapPolygon(coordinates: ring.map { $0.coordinate })
                            .foregroundStyle(self.polygonColor.opacity(0.18))
                            .stroke(self.polygonColor, lineWidth: 2)
                    }
                    ForEach(self.annotations) { annotation in
                        Annotation("", coordinate: annotation.location.coordinate, anchor: .center) {
                            ZStack {
                                if annotation.user == true {
                                    Circle().fill(.white).frame(width: 15, height: 15)
                                }
                                Circle()
                                    .fill(annotation.displayColor)
                                    .frame(width: 11, height: 11)
                            }
                            .accessibilityHidden(true)
                        }
                        .annotationTitles(.hidden)
                    }
                }
                .overlay {
                    PointOfInterestOverlay(symbols: self.poiProjection.symbols, markers: self.layout.request?.items.map(\.marker) ?? [])
                        .equatable()
                    MapAnnotationOverlay(
                        annotations: self.annotations, items: self.layout.request?.items ?? [], placements: self.layout.placements,
                        showsPointsOfInterest: self.showsPointsOfInterest)
                }
                .onMapCameraChange(frequency: .continuous) { context in
                    self.visibleRect = context.rect
                    self.update(self.request(size: geometry.size))
                    self.projectPOIs(poiTrigger)
                }
                // Annotations or size changed while the camera did not: project again from the rectangle the map last reported.
                .onChange(of: trigger) { _, _ in
                    self.update(self.request(size: geometry.size))
                }
                .onChange(of: poiTrigger) { _, newValue in
                    self.projectPOIs(newValue)
                }
                .allowsHitTesting(false)
            }
        }
    }

    private func makePOIProjection(_ trigger: POITrigger) -> PointOfInterestProjection {
        return PointOfInterestProjection.project(trigger.inputs, viewport: CGRect(origin: .zero, size: trigger.size)) {
            self.project($0.coordinate, size: trigger.size)
        }
    }

    private func projectPOIs(_ trigger: POITrigger) {
        let projection = self.makePOIProjection(trigger)
        if projection != self.poiProjection { self.poiProjection = projection }
    }

    private func project(_ coordinate: CLLocationCoordinate2D, size: CGSize) -> CGPoint? {
        guard let visibleRect = self.visibleRect else { return nil }
        return MapProjection.point(for: coordinate, in: visibleRect, size: size)
    }

    private func request(size: CGSize) -> Request {
        let items = self.annotations.compactMap { annotation -> AnnotationLayout.Item? in
            guard let point = self.project(annotation.location.coordinate, size: size) else { return nil }
            let diameter: CGFloat = annotation.user == true ? 15 : 11
            return AnnotationLayout.Item(
                id: annotation.id, point: point,
                marker: CGRect(x: point.x - diameter / 2, y: point.y - diameter / 2, width: diameter, height: diameter),
                size: annotation.showsLabel == true ? MapAnnotationLabel.size : nil)
        }
        return Request(items: items, viewport: CGRect(origin: .zero, size: size))
    }

    private func update(_ request: Request) -> Void {
        guard request != self.layout.request else { return }
        let result = AnnotationLayout.place(request.items, in: request.viewport, previous: self.layout.placements)
        // Geometry and placements publish atomically. Text changes never invalidate this cache.
        self.layout = LayoutState(request: request, placements: result.placements)
    }
}
