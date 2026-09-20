import CoreGraphics
import Foundation

/// Deterministic screen-space label placement. Coordinates and distances are in points.
/// Input order is priority order; identifiers must be unique and stable across refreshes.
public enum AnnotationLayout {
    public static let labelSize = CGSize(width: 131, height: 33)
    public static let viewportInset: CGFloat = 8
    public static let labelSeparation: CGFloat = 6
    public static let markerClearance: CGFloat = 4
    public static let beamLimit = 256
    // Ignore subpixel arithmetic noise before scoring, not inside the sort comparator.
    private static let geometryTolerance: CGFloat = 0.0000001

    public struct Item: Equatable, Sendable {
        public let id: String
        public let point: CGPoint
        /// Actual marker bounds, including any outer ring. Markers are treated as ellipses for connectors.
        public let marker: CGRect
        /// Nil preserves a marker as an obstacle without creating a label.
        public let size: CGSize?

        public init(id: String, point: CGPoint, marker: CGRect, size: CGSize? = AnnotationLayout.labelSize) {
            self.id = id
            self.point = point
            self.marker = marker
            self.size = size
        }
    }

    public struct Connector: Equatable, Sendable {
        public let start: CGPoint
        public let end: CGPoint
    }

    public struct Placement: Equatable, Sendable {
        public let id: String
        public let source: CGPoint
        public let rect: CGRect
        public let connector: Connector?
    }

    public struct Result: Equatable, Sendable {
        public let placements: [Placement]
        /// Diagnostics allow callers to verify the search bound without timing-dependent tests.
        public let peakBeamCount: Int
        public let evaluatedArrangements: Int
    }

    private struct Candidate {
        let placement: Placement
        let penalty: CGFloat
        let moved: Int
        let anchorRank: Int
        let distance: CGFloat
    }

    private struct Arrangement {
        var placements: [Placement] = []
        var penalty: CGFloat = 0
        var moved = 0
        var connectors = 0
        var anchorRank = 0
        var crossings = 0
        var distance: CGFloat = 0
        var order = 0

        func precedes(_ other: Self) -> Bool {
            if self.penalty != other.penalty { return self.penalty < other.penalty }
            if self.connectors != other.connectors { return self.connectors < other.connectors }
            if self.anchorRank != other.anchorRank { return self.anchorRank < other.anchorRank }
            if self.crossings != other.crossings { return self.crossings < other.crossings }
            if self.distance != other.distance { return self.distance < other.distance }
            if self.moved != other.moved { return self.moved < other.moved }
            return self.order < other.order
        }
    }

    /// Tries local anchors, then outward anchors, then a viewport grid only if needed.
    /// A finite beam search preserves every valid label even when no collision-free solution fits.
    public static func place(_ items: [Item], in viewport: CGRect, previous: [Placement] = []) -> Result {
        guard Self.valid(viewport) == true, viewport.width > 0, viewport.height > 0 else {
            return Result(placements: [], peakBeamCount: 0, evaluatedArrangements: 0)
        }
        var identifiers = Set<String>()
        let validItems = items.filter { item in
            return Self.valid(item.marker) && item.point.x.isFinite && item.point.y.isFinite
                && identifiers.insert(item.id).inserted
        }
        let labels = validItems.filter { item in
            guard let size = item.size else { return false }
            return size.width.isFinite && size.height.isFinite && size.width > 0 && size.height > 0
        }
        // Avoid inverted bounds in a viewport smaller than twice the inset.
        let bounds = viewport.insetBy(dx: min(Self.viewportInset, viewport.width / 2), dy: min(Self.viewportInset, viewport.height / 2))
        var best = Arrangement()
        var peak = 0
        var evaluated = 0
        for tier in 0 ... 2 {
            var beam = [Arrangement()]
            for item in labels {
                let candidates = Self.candidates(
                    item, items: validItems, bounds: bounds, previous: previous.first { $0.id == item.id }, tier: tier)
                var next: [Arrangement] = []
                next.reserveCapacity(Self.beamLimit)
                var order = 0
                for partial in beam {
                    for candidate in candidates {
                        var arrangement = partial
                        arrangement.penalty += candidate.penalty
                        arrangement.moved += candidate.moved
                        arrangement.connectors += candidate.placement.connector == nil ? 0 : 1
                        arrangement.anchorRank += candidate.anchorRank
                        arrangement.distance += candidate.distance
                        arrangement.order = order
                        order += 1
                        for placed in partial.placements {
                            arrangement.penalty += Self.area(
                                candidate.placement.rect.insetBy(dx: -Self.labelSeparation, dy: -Self.labelSeparation).intersection(placed.rect))
                            if let first = candidate.placement.connector, let second = placed.connector {
                                if Self.crosses(first, second) == true { arrangement.crossings += 1 }
                            }
                        }
                        arrangement.placements.append(candidate.placement)
                        Self.retain(arrangement, in: &next)
                        evaluated += 1
                    }
                }
                next.sort { $0.precedes($1) }
                beam = next
                peak = max(peak, beam.count)
            }
            if let winner = beam.first {
                if tier == 0 || winner.precedes(best) == true { best = winner }
            }
            if best.penalty == 0 { break }
        }
        return Result(placements: best.placements, peakBeamCount: peak, evaluatedArrangements: evaluated)
    }

    // A max heap keeps only the best 256 partial arrangements, including during expansion.
    private static func retain(_ candidate: Arrangement, in heap: inout [Arrangement]) -> Void {
        if heap.count < Self.beamLimit {
            heap.append(candidate)
            var index = heap.count - 1
            while index > 0 {
                let parent = (index - 1) / 2
                if heap[parent].precedes(heap[index]) == false { break }
                heap.swapAt(parent, index)
                index = parent
            }
        }
        else if let worst = heap.first, candidate.precedes(worst) == true {
            heap[0] = candidate
            var index = 0
            while index * 2 + 1 < heap.count {
                var child = index * 2 + 1
                if child + 1 < heap.count, heap[child].precedes(heap[child + 1]) == true { child += 1 }
                if heap[index].precedes(heap[child]) == false { break }
                heap.swapAt(index, child)
                index = child
            }
        }
    }

    private static func candidates(_ item: Item, items: [Item], bounds: CGRect, previous: Placement?, tier: Int) -> [Candidate] {
        guard let size = item.size else { return [] }
        let normal = Self.anchors(item, size: size, distance: 0)
        let previousOrigin = previous.map {
            CGPoint(x: item.point.x + ($0.rect.minX - $0.source.x), y: item.point.y + ($0.rect.minY - $0.source.y))
        }
        var origins: [CGPoint] = []
        if let previousOrigin = previousOrigin {
            origins.append(previousOrigin)
        }
        origins.append(contentsOf: normal)
        if tier >= 1 {
            for distance in stride(from: 40, through: 160, by: 40) {
                origins.append(contentsOf: Self.anchors(item, size: size, distance: CGFloat(distance)))
            }
        }
        if tier == 2 {
            // Bound pathological caller-provided viewports as well as the beam itself.
            // The app has at most six labels; 32 rows/columns exceeds its useful grid density.
            let columns = min(32, Int(min(31, max(0, (bounds.width - size.width) / (size.width + Self.labelSeparation)))) + 1)
            let rows = min(32, Int(min(31, max(0, (bounds.height - size.height) / (size.height + Self.labelSeparation)))) + 1)
            for row in 0 ..< rows {
                for column in 0 ..< columns {
                    origins.append(
                        CGPoint(
                            x: bounds.minX + CGFloat(column) * (size.width + Self.labelSeparation),
                            y: bounds.minY + CGFloat(row) * (size.height + Self.labelSeparation)))
                }
            }
        }
        var unique: [CGPoint] = []
        return origins.compactMap { origin in
            if unique.contains(origin) == true { return nil }
            unique.append(origin)
            let rect = CGRect(origin: origin, size: size)
            let normalIndex = normal.firstIndex { abs($0.x - origin.x) < 0.000001 && abs($0.y - origin.y) < 0.000001 }
            let isNormal = normalIndex != nil
            let connector = isNormal == true ? nil : Self.connector(from: item, to: rect)
            var penalty = Self.clippedArea(rect, outside: bounds)
            for marker in items {
                // Attached labels intentionally meet their own dot. Coincident dots share
                // that attachment; unrelated markers still reserve the full clearance.
                if isNormal == true, marker.point == item.point { continue }
                penalty += Self.area(rect.intersection(marker.marker.insetBy(dx: -Self.markerClearance, dy: -Self.markerClearance)))
            }
            let retained = previousOrigin == nil || origin == previousOrigin
            let dx = rect.midX - item.point.x
            let dy = rect.midY - item.point.y
            return Candidate(
                placement: Placement(id: item.id, source: item.point, rect: rect, connector: connector), penalty: penalty,
                moved: retained == true ? 0 : 1, anchorRank: normalIndex ?? 0, distance: hypot(dx, dy))
        }
    }

    private static func anchors(_ item: Item, size: CGSize, distance: CGFloat) -> [CGPoint] {
        let left = item.point.x - size.width - distance
        let right = item.point.x + distance
        let above = item.point.y - size.height - distance
        let below = item.point.y + distance
        let centerX = item.point.x - size.width / 2
        let centerY = item.point.y - size.height / 2
        // Corner anchors reproduce the original bottom-leading attachment. Cardinal
        // anchors meet the marker boundary rather than covering half of the dot.
        return [
            CGPoint(x: right, y: above), CGPoint(x: left, y: above), CGPoint(x: right, y: below), CGPoint(x: left, y: below),
            CGPoint(x: centerX, y: item.marker.minY - size.height - distance),
            CGPoint(x: item.marker.maxX + distance, y: centerY),
            CGPoint(x: centerX, y: item.marker.maxY + distance),
            CGPoint(x: item.marker.minX - size.width - distance, y: centerY)
        ]
    }

    private static func connector(from item: Item, to rect: CGRect) -> Connector {
        var end = CGPoint(x: min(max(item.point.x, rect.minX), rect.maxX), y: min(max(item.point.y, rect.minY), rect.maxY))
        if rect.contains(item.point) == true {
            // Even an unavoidable overlap in a tiny viewport must terminate on a boundary.
            let edges = [
                CGPoint(x: rect.minX, y: item.point.y), CGPoint(x: rect.maxX, y: item.point.y),
                CGPoint(x: item.point.x, y: rect.minY), CGPoint(x: item.point.x, y: rect.maxY)
            ]
            end = edges.min { hypot($0.x - item.point.x, $0.y - item.point.y) < hypot($1.x - item.point.x, $1.y - item.point.y) } ?? end
        }
        let dx = end.x - item.point.x
        let dy = end.y - item.point.y
        let radiusX = max(item.marker.width / 2, 0.001)
        let radiusY = max(item.marker.height / 2, 0.001)
        let scale = hypot(dx / radiusX, dy / radiusY)
        if scale == 0 {
            return Connector(start: CGPoint(x: item.point.x + radiusX, y: item.point.y), end: end)
        }
        return Connector(start: CGPoint(x: item.point.x + dx / scale, y: item.point.y + dy / scale), end: end)
    }

    private static func crosses(_ first: Connector, _ second: Connector) -> Bool {
        func side(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> CGFloat {
            return (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
        }
        return side(first.start, first.end, second.start) * side(first.start, first.end, second.end) < 0
            && side(second.start, second.end, first.start) * side(second.start, second.end, first.end) < 0
    }

    private static func clippedArea(_ rect: CGRect, outside bounds: CGRect) -> CGFloat {
        // Sum outside strips instead of subtracting nearly equal rectangle areas.
        // A contained label must score exactly zero, never a tiny negative reward.
        let outsideWidth = min(
            rect.width,
            Self.positiveLength(bounds.minX - rect.minX) + Self.positiveLength(rect.maxX - bounds.maxX))
        let outsideHeight = min(
            rect.height,
            Self.positiveLength(bounds.minY - rect.minY) + Self.positiveLength(rect.maxY - bounds.maxY))
        return outsideWidth * rect.height + outsideHeight * (rect.width - outsideWidth)
    }

    private static func area(_ rect: CGRect) -> CGFloat {
        return rect.isNull == true ? 0 : Self.positiveLength(rect.width) * Self.positiveLength(rect.height)
    }

    private static func positiveLength(_ length: CGFloat) -> CGFloat {
        return length > Self.geometryTolerance ? length : 0
    }

    private static func valid(_ rect: CGRect) -> Bool {
        return rect.origin.x.isFinite && rect.origin.y.isFinite && rect.width.isFinite && rect.height.isFinite && rect.width >= 0
            && rect.height >= 0
    }
}
