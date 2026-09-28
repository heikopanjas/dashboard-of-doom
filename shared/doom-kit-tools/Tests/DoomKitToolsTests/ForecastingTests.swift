@testable import DoomKitTools
import Foundation
import Testing

/// A seeded generator, so every synthetic series is the same on every run.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        self.state &+= 0x9E37_79B9_7F4A_7C15
        var z = self.state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Standard normal, by Box and Muller.
    mutating func gaussian() -> Double {
        let u = Double.random(in: Double.ulpOfOne ..< 1, using: &self)
        let v = Double.random(in: 0 ..< 1, using: &self)
        return sqrt(-2 * log(u)) * cos(2 * .pi * v)
    }
}

/// The kinds of series the app forecasts, made up so the right answer is known.
enum Series {
    static func trend(seed: UInt64, count: Int = 200) -> [Double] {
        var generator = SplitMix64(seed: seed)
        return (0 ..< count).map { 10 + 0.5 * Double($0) + generator.gaussian() }
    }

    static func randomWalk(seed: UInt64, count: Int = 300, start: Double = 100) -> [Double] {
        var generator = SplitMix64(seed: seed)
        var value = start
        return (0 ..< count).map { _ in
            value += generator.gaussian()
            return value
        }
    }

    static func weekly(seed: UInt64, count: Int = 140) -> [Double] {
        var generator = SplitMix64(seed: seed)
        return (0 ..< count).map { 50 + 10 * sin(2 * .pi * Double($0) / 7) + 2 * generator.gaussian() }
    }

    /// Three days of a tidal gauge at 15 minutes: M2, a smaller M4 and a little noise.
    static func tide(seed: UInt64, count: Int = 288) -> [Double] {
        var generator = SplitMix64(seed: seed)
        let m2 = 12.4206 * 4
        return (0 ..< count).map { t in
            let t = Double(t)
            return 3 + 0.8 * sin(2 * .pi * t / m2) + 0.2 * sin(2 * .pi * t / (m2 / 2) + 1) + 0.05 * generator.gaussian()
        }
    }

    /// A dose rate: flat with a little noise, and a brief rise now and then.
    static func spiky(seed: UInt64, count: Int = 240) -> [Double] {
        var generator = SplitMix64(seed: seed)
        return (0 ..< count).map { _ in
            let spike = Double.random(in: 0 ..< 1, using: &generator) < 0.05 ? 0.08 : 0
            return 0.1 + 0.005 * generator.gaussian() + spike
        }
    }
}

struct ForecastingTests {
    private static let start = Date(timeIntervalSince1970: 1_790_000_000)

    private static func points(_ values: [Double], step: TimeInterval = 3600) -> [TimeSeriesPoint] {
        return values.enumerated().map { TimeSeriesPoint(timestamp: Self.start.addingTimeInterval(Double($0.offset) * step), value: $0.element) }
    }

    private static func widths(_ intervals: [ForecastInterval]) -> [Double] {
        return intervals.map { $0.upper - $0.lower }
    }

    @Test func theNormalQuantileIsRight() {
        #expect(abs(Statistics.normalQuantile(0.5)) < 1e-9)
        #expect(abs(Statistics.normalQuantile(0.9) - 1.281_551_565_5) < 1e-6)
        #expect(abs(Statistics.normalQuantile(0.975) - 1.959_963_985) < 1e-6)
        #expect(abs(Statistics.normalQuantile(0.01) + 2.326_347_874) < 1e-6)
        #expect(abs(Statistics.z(coverage: 0.8) - 1.281_551_565_5) < 1e-6)
    }

    @Test func theGridInterpolatesLinearlyFromTheLastPoint() {
        let points = [
            TimeSeriesPoint(timestamp: Self.start, value: 0),
            TimeSeriesPoint(timestamp: Self.start.addingTimeInterval(1800), value: 1),
            TimeSeriesPoint(timestamp: Self.start.addingTimeInterval(7200), value: 4)
        ]
        let grid = TimeSeriesGrid.regularize(points, step: 3600)
        #expect(grid.map(\.timestamp) == [Self.start, Self.start.addingTimeInterval(3600), Self.start.addingTimeInterval(7200)])
        // At one hour, a third of the way from 1 at half an hour to 4 at two hours.
        #expect(grid.map(\.value) == [0, 2, 4])
    }

    @Test func aLongGapEndsTheHistory() {
        let points = [0.0, 1, 2].map { TimeSeriesPoint(timestamp: Self.start.addingTimeInterval($0 * 3600), value: $0) }
            + [10.0, 11].map { TimeSeriesPoint(timestamp: Self.start.addingTimeInterval($0 * 3600), value: $0) }
        let grid = TimeSeriesGrid.regularize(points, step: 3600, maximumGap: 4 * 3600)
        #expect(grid.map(\.value) == [10, 11])
        #expect(TimeSeriesGrid.regularize(points, step: 3600).count == 12)
    }

    @Test func theRandomWalksBandWidensWithTheRootOfTheHorizon() throws {
        let intervals = try RandomWalkModel().predict(Series.randomWalk(seed: 1), horizon: 16, coverage: 0.8)
        let widths = Self.widths(intervals)
        #expect(zip(widths.dropFirst(), widths).allSatisfy { $0 > $1 })
        #expect(abs(widths[15] / widths[0] - 4) < 1e-9)
        #expect(intervals.allSatisfy { $0.mean == Series.randomWalk(seed: 1).last })
    }

    @Test func theDampedTrendsBandWidensAndItsSlopeFades() throws {
        let values = Series.trend(seed: 2)
        let intervals = try DampedTrendModel().predict(values, horizon: 48, coverage: 0.8)
        let widths = Self.widths(intervals)
        #expect(zip(widths.dropFirst(), widths).allSatisfy { $0 >= $1 })
        let steps = zip(intervals.dropFirst(), intervals).map { $0.mean - $1.mean }
        #expect(steps.first ?? 0 > 0)
        #expect(steps.last ?? 1 < steps.first ?? 0)
    }

    @Test func theBaselineStaysFlatAtTheMedian() throws {
        let values = Series.spiky(seed: 3)
        let intervals = try BaselineModel().predict(values, horizon: 24, coverage: 0.8)
        #expect(intervals.allSatisfy { $0 == intervals.first })
        #expect(abs((intervals.first?.mean ?? 0) - 0.1) < 0.005)
        // The spikes reach above the band without dragging the line up.
        #expect((intervals.first?.upper ?? 0) < 0.15)
    }

    @Test func boundsAndTheLogarithmKeepValuesPossible() throws {
        // A falling poll share cannot fall below zero.
        let falling = Self.points((0 ..< 60).map { 12 - 0.3 * Double($0) }, step: 86_400)
        let poll = try Forecaster.forecast(falling, model: DampedTrendModel(), request: ForecastRequest(step: 86_400, horizon: 60, bounds: 0 ... 100))
        #expect(poll.allSatisfy { $0.lower >= 0 && $0.value >= 0 })
        #expect(poll.last?.value == 0)
        // A price forecast in logarithms stays above zero however wide the band.
        let price = Self.points(Series.randomWalk(seed: 4, start: 5).map { max($0, 0.5) }, step: 86_400)
        let forecast = try Forecaster.forecast(
            price, model: RandomWalkModel(), request: ForecastRequest(step: 86_400, horizon: 30, transform: .logarithm))
        #expect(forecast.allSatisfy { $0.lower > 0 })
        // In logarithms the band is wider above than below.
        let last = forecast.last!
        #expect(last.upper - last.value > last.value - last.lower)
        #expect(forecast.first?.timestamp == price.last?.timestamp.addingTimeInterval(86_400))
    }

    @Test func tooShortAHistoryThrows() {
        #expect(throws: ForecastError.insufficientData) {
            try Forecaster.forecast(Self.points([1, 2]), model: DampedTrendModel(), request: ForecastRequest(step: 3600, horizon: 3))
        }
        #expect(throws: ForecastError.insufficientData) {
            try SeasonalModel(period: 7).predict([1, 2, 3, 4, 5, 6, 7, 8], horizon: 3, coverage: 0.8)
        }
        #expect(throws: ForecastError.nonFinite) {
            try Forecaster.forecast(
                Self.points([1, 0, 2, 3, 4]), model: RandomWalkModel(), request: ForecastRequest(step: 3600, horizon: 3, transform: .logarithm))
        }
    }

    @Test func aTideIsDetectedWhereThereIsOne() {
        let periods = HarmonicModel.tidalPeriods.map { $0 * 4 }
        #expect(HarmonicModel.detect(Series.tide(seed: 5), periods: periods) == true)
        #expect(HarmonicModel.detect(Series.randomWalk(seed: 5, count: 288), periods: periods) == false)
        #expect(HarmonicModel.detect(Series.trend(seed: 5, count: 288), periods: periods) == false)
    }
}
