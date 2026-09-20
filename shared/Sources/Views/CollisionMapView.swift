import DoomKitTools
import MapKit
import SwiftUI

struct CollisionMapView: View {
    @Binding var position: MapCameraPosition
    let annotations: [MapAnnotationSnapshot]
    var showsPointsOfInterest = false
    var pointsOfInterest: [PointOfInterest] = []
    @State private var poiProjection = PointOfInterestProjection(symbols: [], projectedCount: 0)

    private struct POITrigger: Equatable {
        let inputs: [PointOfInterestProjection.Input]
        let size: CGSize
    }
    @State private var layout = LayoutState()

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
            MapReader { proxy in
                let poiTrigger = POITrigger(inputs: self.pointsOfInterest.map(PointOfInterestProjection.Input.init), size: geometry.size)
                let trigger = Trigger(
                    annotations: self.annotations.map {
                        GeometryInput(
                            id: $0.id, latitude: $0.location.latitude, longitude: $0.location.longitude,
                            user: $0.user, size: $0.showsLabel == true ? MapAnnotationLabel.size : nil)
                    }, size: geometry.size)
                Map(position: self.$position, interactionModes: []) {
                    ForEach(self.annotations) { annotation in
                        Annotation("", coordinate: annotation.location.coordinate, anchor: .center) {
                            ZStack {
                                if annotation.user == true {
                                    Circle().fill(.white).frame(width: 15, height: 15)
                                }
                                Circle()
                                    .fill(Color.faceplate(selector: annotation.selector))
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
                .onMapCameraChange(frequency: .continuous) { _ in
                    self.update(self.request(proxy: proxy, size: geometry.size))
                    self.projectPOIs(poiTrigger, proxy: proxy)
                }
                .task(id: trigger) {
                    await self.refreshProjection(proxy: proxy, size: geometry.size)
                }
                .task(id: poiTrigger) {
                    for attempt in 0 ..< 8 {
                        do { try await Task.sleep(for: .milliseconds(16)) }
                        catch { return }
                        guard Task.isCancelled == false else { return }
                        let projection = self.makePOIProjection(poiTrigger, proxy: proxy)
                        if projection.projectedCount == poiTrigger.inputs.count || attempt == 7 {
                            if projection != self.poiProjection { self.poiProjection = projection }
                            return
                        }
                    }
                }
                .allowsHitTesting(false)
            }
        }
    }

    private func makePOIProjection(_ trigger: POITrigger, proxy: MapProxy) -> PointOfInterestProjection {
        return PointOfInterestProjection.project(trigger.inputs, viewport: CGRect(origin: .zero, size: trigger.size)) {
            proxy.convert($0.coordinate, to: .local)
        }
    }

    private func projectPOIs(_ trigger: POITrigger, proxy: MapProxy) {
        let projection = self.makePOIProjection(trigger, proxy: proxy)
        if projection != self.poiProjection { self.poiProjection = projection }
    }

    private func refreshProjection(proxy: MapProxy, size: CGSize) async -> Void {
        // MapReader registers the replacement map after SwiftUI's update pass. It can
        // temporarily return nil even when only label visibility changed and the camera did not.
        for attempt in 0 ..< 8 {
            do {
                try await Task.sleep(for: .milliseconds(16))
            }
            catch {
                return
            }
            guard Task.isCancelled == false else { return }
            let request = self.request(proxy: proxy, size: size)
            if request.items.count == self.annotations.count || attempt == 7 {
                self.update(request)
                return
            }
        }
    }

    private func request(proxy: MapProxy, size: CGSize) -> Request {
        let items = self.annotations.compactMap { annotation -> AnnotationLayout.Item? in
            guard let point = proxy.convert(annotation.location.coordinate, to: .local), point.x.isFinite, point.y.isFinite else { return nil }
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
