import CoreGraphics
import DoomKitLocation

struct PointOfInterestProjection: Equatable {
    struct Input: Equatable {
        let id: String
        let category: PointOfInterestCategory
        let location: Location

        init(_ point: PointOfInterest) {
            self.id = point.id
            self.category = point.category
            self.location = point.location
        }
    }
    struct Symbol: Equatable {
        let id: String
        let category: PointOfInterestCategory
        let point: CGPoint
    }
    let symbols: [Symbol]
    let projectedCount: Int

    static func project(_ inputs: [Input], viewport: CGRect, convert: (Location) -> CGPoint?) -> Self {
        let bounds = viewport.insetBy(dx: -5, dy: -5)
        var count = 0
        let symbols = inputs.compactMap { input -> Symbol? in
            guard let point = convert(input.location), point.x.isFinite, point.y.isFinite else { return nil }
            count += 1
            guard bounds.contains(point) == true else { return nil }
            return Symbol(id: input.id, category: input.category, point: point)
        }
        return Self(symbols: symbols, projectedCount: count)
    }
}
