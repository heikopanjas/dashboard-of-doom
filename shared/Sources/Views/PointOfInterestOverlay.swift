import SwiftUI

struct PointOfInterestOverlay: View, Equatable {
    let symbols: [PointOfInterestProjection.Symbol]
    let markers: [CGRect]

    var body: some View {
        Canvas { context, size in
            for marker in self.markers {
                var mask = Path(CGRect(origin: .zero, size: size))
                mask.addEllipse(in: marker.insetBy(dx: -0.5, dy: -0.5))
                context.clip(to: mask, style: FillStyle(eoFill: true))
            }
            // One Core Graphics pass avoids thousands of RenderBox resources.
            // Repeated SwiftUI symbol/image draws crash the GPU encoder at 10,000 POIs.
            context.withCGContext { graphics in
                let images = Dictionary(
                    uniqueKeysWithValues: PointOfInterestCategory.allCases.compactMap { category -> (PointOfInterestCategory, CGImage)? in
                        #if os(macOS)
                        let configuration = NSImage.SymbolConfiguration(paletteColors: [NSColor(category.color)])
                        guard
                            let symbol = NSImage(systemSymbolName: category.symbol, accessibilityDescription: nil)?.withSymbolConfiguration(
                                configuration),
                            let image = symbol.cgImage(forProposedRect: nil, context: nil, hints: nil)
                        else { return nil }
                        #else
                        let configuration = UIImage.SymbolConfiguration(paletteColors: [UIColor(category.color)])
                        guard let symbol = UIImage(systemName: category.symbol, withConfiguration: configuration) else { return nil }
                        let raster = UIGraphicsImageRenderer(size: symbol.size).image { _ in
                            symbol.draw(at: .zero)
                        }
                        guard let image = raster.cgImage else { return nil }
                        #endif
                        return (category, image)
                    })
                for symbol in self.symbols {
                    if let image = images[symbol.category] {
                        let scale = 10 / CGFloat(max(image.width, image.height, 1))
                        let size = CGSize(width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
                        graphics.saveGState()
                        graphics.translateBy(x: symbol.point.x - size.width / 2, y: symbol.point.y + size.height / 2)
                        graphics.scaleBy(x: 1, y: -1)
                        graphics.draw(image, in: CGRect(origin: .zero, size: size))
                        graphics.restoreGState()
                    }
                }
            }
        }
        .accessibilityRepresentation {
            Text(self.summary)
        }
        .allowsHitTesting(false)
    }

    private var summary: String {
        let counts = Dictionary(grouping: self.symbols, by: \.category).mapValues(\.count)
        return "Points of interest. " + PointOfInterestCategory.allCases.map { "\($0.title): \(counts[$0, default: 0])" }.joined(separator: ", ")
    }
}

#Preview("Dense places") {
    PointOfInterestOverlay(
        symbols: (0 ..< 2000).map { index in
            PointOfInterestProjection.Symbol(
                id: String(index), category: PointOfInterestCategory.allCases[index % 5],
                point: CGPoint(x: (index * 37) % 560, y: (index * 61) % 440))
        }, markers: [CGRect(x: 270, y: 210, width: 15, height: 15)]
    )
    .frame(width: 560, height: 440)
}

#Preview("Nearby places") {
    PointOfInterestOverlay(
        symbols: (0 ..< 25).map { index in
            PointOfInterestProjection.Symbol(
                id: String(index), category: PointOfInterestCategory.allCases[index % 5],
                point: CGPoint(x: (index * 97) % 560, y: (index * 113) % 440))
        }, markers: []
    )
    .frame(width: 560, height: 440)
}
