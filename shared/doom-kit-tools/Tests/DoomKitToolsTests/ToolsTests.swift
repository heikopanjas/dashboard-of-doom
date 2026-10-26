import DoomKitLocation
import DoomKitTools
import Foundation
import Testing

struct ToolsTests {
    private func expectValues(_ actual: [Measurement<UnitLength>], _ expected: [Double]) {
        #expect(actual.count == expected.count)
        for (measurement, value) in zip(actual, expected) {
            #expect(abs(measurement.value - value) < 1e-12)
        }
    }

    @Test func capturedSmoothingResults() {
        let input = [1.0, 4, 2, 8, -3].map { Measurement(value: $0, unit: UnitLength.meters) }
        self.expectValues(movingAverage(data: input, windowSize: 3), [1, 2.5, 2.3333333333333335, 4.666666666666667, 2.3333333333333335])
        self.expectValues(exponentialMovingAverage(data: input, alpha: 0.3), [1, 1.9, 1.9299999999999997, 3.7509999999999994, 1.7256999999999993])
        self.expectValues(
            gaussianSmoothing(data: input), [2.1223178627997754, 2.9391433445301174, 3.626678628728009, 3.3788204531720933, 1.2187596024639364])
        #expect(movingAverage(data: input, windowSize: 0) == input)
        #expect(movingAverage(data: input, windowSize: -2) == input)
        #expect(movingAverage(data: input, windowSize: 1) == input)
        self.expectValues(movingAverage(data: input, windowSize: 100), [1, 2.5, 7.0 / 3, 3.75, 2.4])
        #expect(exponentialMovingAverage(data: input, alpha: 1) == input)
        self.expectValues(exponentialMovingAverage(data: input, alpha: 0), [1, 1, 1, 1, 1])
        self.expectValues(gaussianSmoothing(data: input, windowSize: 1), [1, 4, 2, 8, 0])
        let empty: [Measurement<UnitLength>] = []
        #expect(movingAverage(data: empty, windowSize: 3).isEmpty)
        #expect(exponentialMovingAverage(data: empty, alpha: 0.3).isEmpty)
        #expect(gaussianSmoothing(data: empty).isEmpty)
        self.expectValues(gaussianSmoothing(data: [Measurement(value: -2, unit: UnitLength.meters)]), [0])
    }

    @Test(arguments: [-3, 0, 2, 4]) func invalidGaussianWindows(window: Int) {
        let input = [Measurement(value: -2, unit: UnitLength.meters)]
        #expect(gaussianSmoothing(data: input, windowSize: window) == input)
    }

    @Test(arguments: [0.0, -1, Double.infinity, -Double.infinity, Double.nan])
    func invalidGaussianSigma(sigma: Double) {
        let input = [Measurement(value: -2, unit: UnitLength.meters)]
        #expect(gaussianSmoothing(data: input, sigma: sigma) == input)
    }

    @Test func mixedUnits() {
        let input = [Measurement(value: 1, unit: UnitLength.meters), Measurement(value: 100, unit: UnitLength.centimeters)]
        let gaussian = gaussianSmoothing(data: input)
        self.expectValues(gaussian, [1, 100])
        #expect(gaussian.map { $0.unit } == input.map { $0.unit })
        let moving = movingAverage(data: input, windowSize: 2)
        self.expectValues(moving, [1, 50.5])
        #expect(moving.allSatisfy { $0.unit == .meters })
        self.expectValues(exponentialMovingAverage(data: input, alpha: 0.5), [1, 50.5])
    }

    @Test func forecastingAndValidation() throws {
        let predictor = ARIMAPredictor(interval: .hourly)
        #expect(throws: ARIMAError.self) { try predictor.forecast(duration: 3600) }
        let points = [2.0, 3, 5, 4, 8, 7, 9, 12].enumerated().map {
            TimeSeriesPoint(timestamp: Date(timeIntervalSince1970: Double($0.offset) * 3600), value: $0.element)
        }
        try predictor.addData(points)
        let prediction = try predictor.forecast(duration: 10800)
        let expected = [11.61111111111111, 11.474396669363863, 11.318917389383147]
        #expect(prediction.forecasts.count == 3)
        for (index, point) in prediction.forecasts.enumerated() {
            #expect(abs(point.value - expected[index]) < 1e-12)
            #expect(point.timestamp == Date(timeIntervalSince1970: Double(index + 8) * 3600))
            #expect(abs(prediction.confidenceIntervals[index].upper - point.value - 6.60527062276785) < 1e-12)
            #expect(abs(point.value - prediction.confidenceIntervals[index].lower - 6.60527062276785) < 1e-12)
        }
        #expect(throws: ARIMAError.self) { try predictor.addData([TimeSeriesPoint(timestamp: .distantPast, value: 2)]) }
        predictor.clearData()
        #expect(throws: ARIMAError.self) { try predictor.forecast(duration: 3600) }
        #expect(ARIMAParameters(p: -1, d: -2, q: -3).p == 0)
        #expect(TimeSeriesInterval.quarterHourly.interval == 900)
        #expect(TimeSeriesInterval.daily.interval == 86400)
        #expect(TimeSeriesInterval.custom(42).interval == 42)
    }

    @Test func geometryAndSymbols() throws {
        let center = Location(latitude: 0, longitude: 0)
        let box = calculateBoundingBox(center: center, radiusInMeters: 111320)
        #expect(box.minLatitude == -1 && box.maxLatitude == 1)
        #expect(box.minLongitude == -1 && box.maxLongitude == 1)
        let polygon = [center, Location(latitude: 0, longitude: 2), Location(latitude: 2, longitude: 2), Location(latitude: 2, longitude: 0)]
        let inside = Location(latitude: 1, longitude: 1)
        let outside = Location(latitude: 1, longitude: 3)
        #expect(PolygonProximityCalculator.isPointInPolygon(point: inside, polygon: polygon))
        #expect(PolygonProximityCalculator.isPointInPolygon(point: outside, polygon: polygon) == false)
        #expect(PolygonProximityCalculator.isPointInPolygon(point: inside, polygon: []) == false)
        #expect(PolygonProximityCalculator.nearestPointOnPolygon(from: inside, to: []) == nil)
        let nearest = try #require(PolygonProximityCalculator.nearestPointOnPolygon(from: outside, to: polygon))
        #expect(nearest.point == Location(latitude: 1, longitude: 2))
        #expect(nearest.distance > 111000 && nearest.distance < 112000)
        #expect(PolygonProximityCalculator.nearestPointOnPolygonFast(from: outside, to: polygon)?.squaredDistance == 1)
        #expect(PolygonProximityCalculator.nearestPointOnLineSegment(point: outside, lineStart: center, lineEnd: center) == center)
        // An open polyline has no closing edge back to the first vertex, unlike nearestPointOnPolygon.
        let southwest = Location(latitude: 1, longitude: -1)
        let polylineNearest = try #require(PolygonProximityCalculator.nearestPointOnPolyline(from: southwest, to: polygon))
        #expect(polylineNearest.point == Location(latitude: 0, longitude: 0))
        let closedNearest = try #require(PolygonProximityCalculator.nearestPointOnPolygon(from: southwest, to: polygon))
        #expect(closedNearest.point == Location(latitude: 1, longitude: 0))
        #expect(polylineNearest.distance > closedNearest.distance)
        #expect(PolygonProximityCalculator.nearestPointOnPolyline(from: inside, to: []) == nil)
        #expect(PolygonProximityCalculator.nearestPointOnPolyline(from: inside, to: [center]) == nil)
        #expect(PolygonProximityCalculator.nearestPoints(from: outside, to: polygon, count: 2).count == 2)
        #expect(PolygonProximityCalculator.isApproachingPolygon(location: outside, polygon: polygon, threshold: 112000))
        #expect(PolygonProximityCalculator.analyzeLocationRelativeToPolygon(location: inside, polygon: polygon).isInside)
        let fast = FastPolygonProximity()
        #expect(fast.nearestPoint(from: outside) == nil)
        fast.setPolygon(polygon)
        #expect(fast.nearestPoint(from: outside)?.point == nearest.point)
        #expect(center.distance(to: center) == 0)
        #expect(outside.squaredDistance(to: inside) == 4)
        #expect(inside.clLocationCoordinate2D.latitude == 1)
        #expect(MathematicalSymbols.mathematicalBoldCapitalOmega.rawValue == "𝛀")
        #expect(MathematicalSymbols.mathematicalSubscriptZero.rawValue == "₀")
        #expect(MathematicalSymbols.levelLeft.rawValue == "⌊")
    }

    @Test func concurrentLogger() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let logger = Trace(minimumLevel: .info, showColors: false, dateFormat: "yyyy", logFile: url.path)
        logger.debug("filtered")
        // Preserve the original lexical raw-value filtering, including ERROR < INFO.
        logger.error("also filtered")
        await withTaskGroup(of: Void.self) { group in
            for index in 0 ..< 100 {
                group.addTask { logger.info("entry %d", index, file: "Fixture.swift", function: "write()", line: 7) }
            }
        }
        logger.warning("done", file: "Fixture.swift", function: "write()", line: 8)
        let lines = try String(contentsOf: url, encoding: .utf8).split(separator: "\n")
        #expect(lines.count == 101)
        for index in 0 ..< 100 {
            #expect(lines.filter { $0.hasSuffix("[INFO] [Fixture.swift:7 write()] entry \(index)") }.count == 1)
        }
        #expect(lines.last?.hasSuffix("[WARNING] [Fixture.swift:8 write()] done") == true)
    }
}
