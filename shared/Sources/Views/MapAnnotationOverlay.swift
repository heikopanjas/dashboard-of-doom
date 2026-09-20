import DoomKitTools
import SwiftUI

struct MapAnnotationOverlay: View {
    let annotations: [MapAnnotationSnapshot]
    let items: [AnnotationLayout.Item]
    let placements: [AnnotationLayout.Placement]
    var showsPointsOfInterest = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            Canvas { context, size in
                // Clip each marker separately so even coincident native dots stay above the lines.
                for item in self.items {
                    var mask = Path(CGRect(origin: .zero, size: size))
                    mask.addEllipse(in: item.marker.insetBy(dx: -0.5, dy: -0.5))
                    context.clip(to: mask, style: FillStyle(eoFill: true))
                }
                for placement in self.placements {
                    if let connector = placement.connector,
                        let annotation = self.annotations.first(where: { $0.id == placement.id })
                    {
                        var path = Path()
                        path.move(to: connector.start)
                        path.addLine(to: connector.end)
                        context.stroke(path, with: .color(Color.faceplate(selector: annotation.selector)), lineWidth: 1)
                    }
                }
            }
            .accessibilityHidden(true)
            ForEach(self.annotations) { annotation in
                if let placement = self.placements.first(where: { $0.id == annotation.id }) {
                    MapAnnotationLabel(selector: annotation.selector, icon: annotation.icon, faceplate: annotation.faceplate,
                                       backgroundOpacity: self.showsPointsOfInterest == true ? 1.0 : 0.5)
                        .position(x: placement.rect.midX, y: placement.rect.midY)
                }
            }
        }
        .allowsHitTesting(false)
        .transaction { $0.animation = nil }
    }
}
