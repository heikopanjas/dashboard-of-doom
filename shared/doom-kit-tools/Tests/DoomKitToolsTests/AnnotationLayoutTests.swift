import CoreGraphics
import DoomKitTools
import Foundation
import Testing

struct AnnotationLayoutTests {
    private let viewport = CGRect(x: 0, y: 0, width: 600, height: 400)

    private func item(
        _ id: Int, x: CGFloat = 300, y: CGFloat = 200, size: CGSize? = AnnotationLayout.labelSize, diameter: CGFloat = 11
    ) -> AnnotationLayout.Item {
        return AnnotationLayout.Item(
            id: String(id), point: CGPoint(x: x, y: y),
            marker: CGRect(x: x - diameter / 2, y: y - diameter / 2, width: diameter, height: diameter), size: size)
    }

    private func verifyClear(
        _ result: AnnotationLayout.Result, items: [AnnotationLayout.Item], viewport: CGRect, sourceLocation: SourceLocation = #_sourceLocation
    ) -> Void {
        #expect(result.placements.map(\.id) == items.filter { $0.size != nil }.map(\.id), sourceLocation: sourceLocation)
        for (index, placement) in result.placements.enumerated() {
            #expect(viewport.insetBy(dx: 8, dy: 8).contains(placement.rect), sourceLocation: sourceLocation)
            for other in result.placements.dropFirst(index + 1) {
                let intersection = placement.rect.insetBy(dx: -6, dy: -6).intersection(other.rect)
                #expect(intersection.isNull || intersection.width * intersection.height == 0, sourceLocation: sourceLocation)
            }
            for item in items {
                if placement.connector == nil, placement.source == item.point { continue }
                let intersection = placement.rect.intersection(item.marker.insetBy(dx: -4, dy: -4))
                #expect(intersection.isNull || intersection.width * intersection.height == 0, sourceLocation: sourceLocation)
            }
        }
        #expect(result.peakBeamCount <= 256, sourceLocation: sourceLocation)
    }

    @Test func separatedPoints() -> Void {
        let items = [self.item(0, x: 100, y: 100), self.item(1, x: 450, y: 300)]
        let result = AnnotationLayout.place(items, in: self.viewport)
        self.verifyClear(result, items: items, viewport: self.viewport)
        #expect(result.placements.allSatisfy { $0.connector == nil })
    }

    @Test(arguments: 2 ... 6)
    func coincidentPoints(count: Int) -> Void {
        let items = (0 ..< count).map { self.item($0) }
        let result = AnnotationLayout.place(items, in: self.viewport)
        self.verifyClear(result, items: items, viewport: self.viewport)
        #expect(AnnotationLayout.place(items, in: self.viewport) == result)
        #expect(AnnotationLayout.place(items, in: self.viewport, previous: result.placements).placements == result.placements)
    }

    @Test func denseClusterAndConnectors() throws {
        let items = (0 ..< 6).map { self.item($0, x: 285 + CGFloat($0 * 5), y: 190 + CGFloat($0 * 3)) }
        let viewport = CGRect(x: 0, y: 0, width: 420, height: 320)
        let result = AnnotationLayout.place(items, in: viewport)
        self.verifyClear(result, items: items, viewport: viewport)
        let connected = result.placements.filter { $0.connector != nil }
        #expect(connected.isEmpty == false)
        for placement in connected {
            let connector = try #require(placement.connector)
            let item = try #require(items.first { $0.id == placement.id })
            #expect(abs(hypot(connector.start.x - item.point.x, connector.start.y - item.point.y) - item.marker.width / 2) < 0.0001)
            #expect(connector.end.x >= placement.rect.minX && connector.end.x <= placement.rect.maxX)
            #expect(connector.end.y >= placement.rect.minY && connector.end.y <= placement.rect.maxY)
            #expect(
                connector.end.x == placement.rect.minX || connector.end.x == placement.rect.maxX || connector.end.y == placement.rect.minY
                    || connector.end.y == placement.rect.maxY)
            #expect(connector.end.x == min(max(item.point.x, placement.rect.minX), placement.rect.maxX))
            #expect(connector.end.y == min(max(item.point.y, placement.rect.minY), placement.rect.maxY))
        }
    }

    @Test func edgesAndMixedSizes() -> Void {
        let items = [
            self.item(0, x: 1, y: 1), self.item(1, x: 599, y: 1, size: CGSize(width: 90, height: 45)),
            self.item(2, x: 1, y: 399, size: CGSize(width: 150, height: 25)), self.item(3, x: 599, y: 399)
        ]
        self.verifyClear(AnnotationLayout.place(items, in: self.viewport), items: items, viewport: self.viewport)
    }

    @Test func markerWithoutLabelStillReservesClearance() -> Void {
        let items = [self.item(0, size: nil, diameter: 15), self.item(1, y: 240), self.item(2, x: 320)]
        self.verifyClear(AnnotationLayout.place(items, in: self.viewport), items: items, viewport: self.viewport)
    }

    @Test func geometryAndVisibilityChanges() -> Void {
        let initial = (0 ..< 6).map { self.item($0) }
        let previous = AnnotationLayout.place(initial, in: self.viewport).placements
        let moved = (0 ..< 6).map { self.item($0, x: 320, y: 210) }
        let result = AnnotationLayout.place(moved, in: self.viewport, previous: previous)
        self.verifyClear(result, items: moved, viewport: self.viewport)
        for (old, new) in zip(previous, result.placements) {
            #expect(new.rect.minX - old.rect.minX == 20)
            #expect(new.rect.minY - old.rect.minY == 10)
        }
        let visible = Array(moved.prefix(3))
        let reduced = AnnotationLayout.place(visible, in: self.viewport, previous: result.placements)
        self.verifyClear(reduced, items: visible, viewport: self.viewport)
        let resized = CGRect(x: 0, y: 0, width: 400, height: 300)
        self.verifyClear(AnnotationLayout.place(visible, in: resized, previous: reduced.placements), items: visible, viewport: resized)
        let changedSize = [self.item(0, size: CGSize(width: 200, height: 60))]
        let resizedLabel = AnnotationLayout.place(changedSize, in: self.viewport, previous: previous)
        #expect(resizedLabel.placements.first?.rect.size == CGSize(width: 200, height: 60))
        self.verifyClear(resizedLabel, items: changedSize, viewport: self.viewport)
    }

    @Test(arguments: [CGSize(width: 100, height: 70), CGSize(width: 5, height: 5)])
    func undersizedViewportIsBounded(size: CGSize) -> Void {
        let items = (0 ..< 6).map { self.item($0, x: size.width / 2, y: size.height / 2) }
        let viewport = CGRect(origin: .zero, size: size)
        let result = AnnotationLayout.place(items, in: viewport)
        #expect(result.placements.count == 6)
        #expect(result.peakBeamCount <= AnnotationLayout.beamLimit)
        #expect(result.evaluatedArrangements < 200_000)
        #expect(AnnotationLayout.place(items, in: viewport) == result)
    }

    @Test func isolatedLabelAttachesAboveRight() throws {
        let item = self.item(0)
        let placement = try #require(AnnotationLayout.place([item], in: self.viewport).placements.first)
        #expect(placement.rect.minX == item.point.x)
        #expect(placement.rect.maxY == item.point.y)
        #expect(placement.connector == nil)
    }

    @Test func crowdedOffsetsDisappearWhenSpaceOpens() throws {
        let crowded = (0 ..< 6).map { self.item($0) }
        let previous = AnnotationLayout.place(crowded, in: self.viewport).placements
        let displaced = try #require(previous.first { $0.connector != nil })
        let survivor = try #require(crowded.first { $0.id == displaced.id })
        let result = AnnotationLayout.place([survivor], in: self.viewport, previous: previous)
        let placement = try #require(result.placements.first)
        #expect(placement.connector == nil)
        #expect(placement.rect.minX == survivor.point.x)
        #expect(placement.rect.maxY == survivor.point.y)

        let expanded = CGRect(x: 0, y: 0, width: 1800, height: 800)
        let separated = (0 ..< 6).map { self.item($0, x: 150 + CGFloat($0 * 280), y: 400) }
        let settled = AnnotationLayout.place(separated, in: expanded, previous: previous)
        self.verifyClear(settled, items: separated, viewport: expanded)
        #expect(settled.placements.allSatisfy { $0.connector == nil })
    }

    @Test(arguments: [126.50000000000003, 126.1234567, 211.1234567])
    func roundingDoesNotDisplaceUnobstructedLabels(x: Double) throws {
        let item = self.item(0, x: x, y: 181.9876543)
        let result = AnnotationLayout.place([item], in: self.viewport)
        let placement = try #require(result.placements.first)
        #expect(placement.connector == nil)
        #expect(placement.rect.minX == item.point.x)
        #expect(abs(placement.rect.maxY - item.point.y) < 0.000001)
    }

    @Test func fractionalCrowdingDoesNotLeaveConnectors() throws {
        let crowded = (0 ..< 6).map { self.item($0, x: 126.50000000000003, y: 181.9876543) }
        let previous = AnnotationLayout.place(crowded, in: self.viewport).placements
        for item in crowded {
            let result = AnnotationLayout.place([item], in: self.viewport, previous: previous)
            let placement = try #require(result.placements.first)
            #expect(placement.connector == nil)
            #expect(placement.rect.minX == item.point.x)
            #expect(abs(placement.rect.maxY - item.point.y) < 0.000001)
        }
    }

    @Test func realClippingStillOverridesPreferredAnchor() throws {
        let item = self.item(0, x: 500.1234567, y: 181.9876543)
        let result = AnnotationLayout.place([item], in: self.viewport)
        let placement = try #require(result.placements.first)
        self.verifyClear(result, items: [item], viewport: self.viewport)
        #expect(placement.rect.minX != item.point.x)
        #expect(placement.connector == nil)
    }

    @Test func fractionalProjectionRetainsRelativePlacement() -> Void {
        let items = (0 ..< 6).map { self.item($0, x: 300.1234567, y: 200.9876543) }
        let previous = AnnotationLayout.place(items, in: self.viewport).placements
        let moved = (0 ..< 6).map { self.item($0, x: 300.1234587, y: 200.9876593) }
        let result = AnnotationLayout.place(moved, in: self.viewport, previous: previous)
        for (old, new) in zip(previous, result.placements) {
            #expect(abs((new.rect.minX - new.source.x) - (old.rect.minX - old.source.x)) < 0.000001)
            #expect(abs((new.rect.minY - new.source.y) - (old.rect.minY - old.source.y)) < 0.000001)
            #expect((new.connector == nil) == (old.connector == nil))
        }
    }

    @Test func gridFallbackForOffscreenCluster() -> Void {
        let items = (0 ..< 6).map { self.item($0, x: -1000, y: -1000) }
        let result = AnnotationLayout.place(items, in: self.viewport)
        self.verifyClear(result, items: items, viewport: self.viewport)
        #expect(result.placements.allSatisfy { $0.connector != nil })
        #expect(result == AnnotationLayout.place(items, in: self.viewport))
    }

    @Test func invalidProjectionAndEmptyInput() -> Void {
        let items = [self.item(0, x: .nan), self.item(1)]
        #expect(AnnotationLayout.place(items, in: self.viewport).placements.map(\.id) == ["1"])
        #expect(AnnotationLayout.place([], in: self.viewport).placements.isEmpty)
        #expect(AnnotationLayout.place(items, in: .zero).placements.isEmpty)
    }
}
