@testable import DoomKitTools
import Foundation
import Testing

/// Each model on the kind of series it is for, against repeating the last value. A MASE below 1 beats that; the 80 % band should hold
/// about 80 % of what happened.
struct BacktestTests {
    private static let seeds: [UInt64] = [11, 12, 13, 14, 15]

    /// The results of several seeds together, so one lucky or unlucky series does not decide.
    private static func pooled(_ series: (UInt64) -> [Double], model: some ForecastModel, horizon: Int, origins: Int = 5) throws -> BacktestResult {
        var mae = 0.0
        var naive = 0.0
        var inside = 0.0
        var count = 0
        for seed in Self.seeds {
            let result = try #require(Backtest.evaluate(series(seed), model: model, horizon: horizon, origins: origins))
            mae += result.mae * Double(result.count)
            naive += result.naiveMAE * Double(result.count)
            inside += result.coverage * Double(result.count)
            count += result.count
        }
        return BacktestResult(mae: mae / Double(count), naiveMAE: naive / Double(count), coverage: inside / Double(count), count: count)
    }

    @Test func theDampedTrendFollowsATrend() throws {
        let result = try Self.pooled({ Series.trend(seed: $0) }, model: DampedTrendModel(), horizon: 12)
        #expect(result.mase < 0.5)
        #expect(result.coverage > 0.65)
    }

    @Test func nothingBeatsTheLastValueOnARandomWalkAndItsBandHolds() throws {
        let result = try Self.pooled({ Series.randomWalk(seed: $0) }, model: RandomWalkModel(), horizon: 12)
        // The random walk is the last value, so it ties exactly.
        #expect(abs(result.mase - 1) < 1e-9)
        #expect(result.coverage > 0.7 && result.coverage < 0.9)
    }

    @Test func theWeeklyPatternBeatsTheLastValue() throws {
        let seasonal = try Self.pooled({ Series.weekly(seed: $0) }, model: SeasonalModel(period: 7), horizon: 14)
        let trend = try Self.pooled({ Series.weekly(seed: $0) }, model: DampedTrendModel(), horizon: 14)
        #expect(seasonal.mase < 0.5)
        #expect(seasonal.mase < trend.mase)
    }

    @Test func theTideBeatsTheLastValue() throws {
        let model = HarmonicModel(periods: HarmonicModel.tidalPeriods.map { $0 * 4 })
        let result = try Self.pooled({ Series.tide(seed: $0, count: 384) }, model: model, horizon: 48, origins: 2)
        #expect(result.mase < 0.3)
    }

    @Test func theUsualRangeHoldsTheQuietDays() throws {
        let result = try Self.pooled({ Series.spiky(seed: $0) }, model: BaselineModel(), horizon: 24)
        #expect(result.mase < 1)
        #expect(result.coverage > 0.7 && result.coverage < 0.95)
    }

    @Test func tooShortASeriesHasNoBacktest() {
        #expect(Backtest.evaluate([1, 2, 3], model: DampedTrendModel(), horizon: 5, origins: 3) == nil)
        #expect(BacktestResult(mae: 0, naiveMAE: 0, coverage: 1, count: 1).mase == 1)
    }
}
