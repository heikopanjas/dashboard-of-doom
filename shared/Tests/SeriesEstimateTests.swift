import DoomKitProcess
import DoomKitTools
import Foundation
import Testing

@Suite struct SeriesEstimateTests {
    private static let now = Date(timeIntervalSince1970: 1_790_000_000)

    /// Values `step` apart, the last one `age` before now.
    private static func series(
        _ values: [Double], step: TimeInterval, age: TimeInterval = 0, unit: Dimension, quality: ProcessQuality = .good
    ) -> [ProcessValue<Dimension>] {
        let end = Self.now.addingTimeInterval(-age)
        return values.enumerated().map { index, value in
            ProcessValue<Dimension>(
                value: Measurement(value: value, unit: unit), quality: quality,
                timestamp: end.addingTimeInterval(-Double(values.count - 1 - index) * step))
        }
    }

    /// A model that always says zero, which nothing should be shown from.
    private struct Zero: ForecastModel {
        var name: String { "zero" }
        var minimumHistory: Int { 2 }
        func predict(_ values: [Double], horizon: Int, coverage: Double) throws -> [ForecastInterval] {
            return [ForecastInterval](repeating: ForecastInterval(mean: 0, lower: 0, upper: 0), count: horizon)
        }
    }

    // MARK: - The shared part

    @Test func anEstimateIsLabelledWithItsMethodAndKeepsTheUnit() throws {
        let raw = Self.series((0 ..< 48).map { 0.1 + 0.001 * sin(Double($0)) }, step: 3600, unit: UnitRadiation.microsieverts)
        let estimate = try #require(
            SeriesEstimate.make(from: raw, model: BaselineModel(), request: ForecastRequest(step: 3600, horizon: 6), maximumAge: 3600, now: Self.now))
        #expect(estimate.origin == .estimate("usual range"))
        #expect(estimate.origin.isProvider == false)
        #expect(estimate.points.count == 6)
        #expect(estimate.points.first?.timestamp == Self.now.addingTimeInterval(3600))
        #expect(estimate.points.first?.value.unit == UnitRadiation.microsieverts)
        #expect(estimate.points.allSatisfy { $0.hasBand })
    }

    @Test func aFeedThatStoppedIsNotContinued() {
        let raw = Self.series((0 ..< 48).map { Double($0) }, step: 3600, age: 7200, unit: UnitLength.meters)
        #expect(SeriesEstimate.make(from: raw, model: DampedTrendModel(), request: ForecastRequest(step: 3600, horizon: 6), maximumAge: 3600, now: Self.now) == nil)
        #expect(SeriesEstimate.make(from: [], model: DampedTrendModel(), request: ForecastRequest(step: 3600, horizon: 6), maximumAge: 3600, now: Self.now) == nil)
    }

    @Test func aModelWorseThanTheLastValueGivesWayToIt() throws {
        let raw = Self.series((0 ..< 60).map { 50 + Double($0 % 5) }, step: 3600, unit: UnitLength.meters)
        let estimate = try #require(
            SeriesEstimate.make(from: raw, model: Zero(), request: ForecastRequest(step: 3600, horizon: 6), maximumAge: 3600, now: Self.now))
        #expect(estimate.origin == .estimate("last value"))
        #expect(estimate.points.first?.value.value == 54)
    }

    @Test func valuesOfUnknownQualityAreLeftOut() throws {
        var raw = Self.series((0 ..< 48).map { _ in 1.0 }, step: 3600, unit: UnitLength.meters)
        raw.append(ProcessValue(value: Measurement(value: 0, unit: UnitLength.meters), quality: .unknown, timestamp: Self.now.addingTimeInterval(1800)))
        let estimate = try #require(
            SeriesEstimate.make(from: raw, model: BaselineModel(), request: ForecastRequest(step: 3600, horizon: 3), maximumAge: 3600, now: Self.now))
        #expect(estimate.points.first?.timestamp == Self.now.addingTimeInterval(3600))
        #expect(estimate.points.first?.value.value == 1)
    }

    // MARK: - Per source

    @Test func radiationIsItsUsualRangeForADay() throws {
        let values: [Double] = (0 ..< 168).map { (hour: Int) -> Double in
            let spike: Double = hour % 40 == 0 ? 0.08 : 0
            return 0.1 + 0.004 * sin(Double(hour) / 3) + spike
        }
        let estimate = try #require(RadiationController.estimate(from: Self.series(values, step: 3600, unit: UnitRadiation.microsieverts), now: Self.now))
        #expect(estimate.origin == .estimate("usual range"))
        #expect(estimate.points.count == 24)
        #expect(Set(estimate.points.map(\.value.value)).count == 1)
        #expect(abs((estimate.points.first?.value.value ?? 0) - 0.1) < 0.01)
    }

    @Test func energyIsTheLastPriceWithABandWiderAboveThanBelow() throws {
        let values = (0 ..< 250).map { 80 + 5 * sin(Double($0) / 9) + Double($0 % 3) }
        let estimate = try #require(EnergyController.estimate(from: Self.series(values, step: 86_400, unit: UnitOilPrice.usDollarsPerBarrel), now: Self.now))
        #expect(estimate.origin == .estimate("last value"))
        #expect(estimate.points.count == 30)
        let last = try #require(estimate.points.last)
        #expect(abs(last.value.value - (values.last ?? 0)) < 1e-9)
        #expect(try #require(last.upper) - last.value.value > last.value.value - (try #require(last.lower)))
        #expect(estimate.points.allSatisfy { ($0.lower ?? 0) > 0 })
        // A mirror a fortnight behind is not continued.
        #expect(EnergyController.estimate(from: Self.series(values, step: 86_400, age: 14 * 86_400, unit: UnitOilPrice.usDollarsPerBarrel), now: Self.now) == nil)
    }

    @Test func aTidalGaugeFollowsItsTide() throws {
        let m2 = 12.4206 * 4
        let values: [Double] = (0 ..< 288).map { (step: Int) -> Double in
            let t = Double(step)
            let tide: Double = 0.8 * sin(2 * Double.pi * t / m2)
            return 3 + tide + 0.01 * sin(t * 1.7)
        }
        let estimate = try #require(LevelController.estimate(from: Self.series(values, step: 900, unit: UnitLength.meters), now: Self.now))
        #expect(estimate.origin == .estimate("tide"))
        #expect(estimate.points.count == 96)
        #expect(estimate.points.first?.timestamp == Self.now.addingTimeInterval(900))
        // It keeps swinging rather than settling.
        let forecast = estimate.points.map(\.value.value)
        #expect((forecast.max() ?? 0) - (forecast.min() ?? 0) > 1)
    }

    @Test func anyOtherGaugeFollowsItsTrendForTwelveHours() throws {
        let values: [Double] = (0 ..< 288).map { (step: Int) -> Double in
            let t = Double(step)
            return 2 + 0.0005 * t + 0.002 * sin(t * 1.3)
        }
        let estimate = try #require(LevelController.estimate(from: Self.series(values, step: 900, unit: UnitLength.meters), now: Self.now))
        #expect(estimate.origin == .estimate("trend"))
        #expect(estimate.points.count == 12)
        #expect(estimate.points.first?.timestamp == Self.now.addingTimeInterval(3600))
        #expect((estimate.points.last?.value.value ?? 0) > (values.last ?? 0))
    }

    @Test func pollSharesStayBetweenZeroAndAHundred() throws {
        // Every few days a poll, one party falling fast, one steady.
        let days = stride(from: 0, to: 360, by: 4)
        let falling = days.map { 20 - 0.05 * Double($0) }
        let steady = days.map { 30 + Double($0 % 3) }
        let polls: [ProcessSelector: [ProcessValue<Dimension>]] = [
            .survey(.fdp): Self.series(falling, step: 4 * 86_400, unit: UnitPercentage.percent, quality: .uncertain),
            .survey(.spd): Self.series(steady, step: 4 * 86_400, unit: UnitPercentage.percent, quality: .uncertain)
        ]
        let estimates = SurveyController.estimates(from: polls, now: Self.now)
        let fdp = try #require(estimates[.survey(.fdp)])
        #expect(fdp.origin == .estimate("trend"))
        // Thirteen weeks, a week apart from the last poll.
        #expect(fdp.points.count == 13)
        #expect(fdp.points.first?.timestamp == Self.now.addingTimeInterval(7 * 86_400))
        #expect(fdp.points.allSatisfy { $0.value.value >= 0 && ($0.lower ?? 0) >= 0 && ($0.upper ?? 0) <= 100 })
        #expect(estimates[.survey(.spd)] != nil)
        // A parliament without a poll for half a year is not continued.
        let old: [ProcessSelector: [ProcessValue<Dimension>]] = [.survey(.spd): Self.series(steady, step: 4 * 86_400, age: 180 * 86_400, unit: UnitPercentage.percent)]
        #expect(SurveyController.estimates(from: old, now: Self.now).isEmpty == true)
    }

    @Test func pollsAreAveragedPerWeekBackFromTheLastPoll() throws {
        // Two polls three days apart in the newest week, one in the week before.
        let polls = [
            ProcessValue<Dimension>(value: Measurement(value: 10, unit: UnitPercentage.percent), quality: .uncertain, timestamp: Self.now.addingTimeInterval(-9 * 86_400)),
            ProcessValue<Dimension>(value: Measurement(value: 20, unit: UnitPercentage.percent), quality: .uncertain, timestamp: Self.now.addingTimeInterval(-3 * 86_400)),
            ProcessValue<Dimension>(value: Measurement(value: 30, unit: UnitPercentage.percent), quality: .uncertain, timestamp: Self.now)
        ]
        let weekly = SurveyController.weekly(polls)
        #expect(weekly.map(\.value.value) == [10, 25])
        #expect(weekly.map(\.timestamp) == [Self.now.addingTimeInterval(-7 * 86_400), Self.now])
    }

    @Test func noisyPollsAroundATrendFollowTheTrend() throws {
        // A poll every two days, sinking a point a month, with the two or three points pollsters differ by.
        let offsets: [Double] = [2.5, -1.5, 0.5, -2.5, 1.5, -0.5]
        let shares: [Double] = (0 ..< 180).map { (poll: Int) -> Double in
            let trend: Double = 25 - Double(poll) * 2 / 30
            return trend + offsets[poll % offsets.count]
        }
        let polls: [ProcessSelector: [ProcessValue<Dimension>]] = [
            .survey(.spd): Self.series(shares, step: 2 * 86_400, unit: UnitPercentage.percent, quality: .uncertain)
        ]
        let estimate = try #require(SurveyController.estimates(from: polls, now: Self.now)[.survey(.spd)])
        #expect(estimate.origin == .estimate("trend"))
        #expect((estimate.points.last?.value.value ?? 100) < (shares.suffix(14).reduce(0, +) / 14))
    }

    @Test func covidCountsFollowTheReportingWeek() throws {
        let cases = (0 ..< 90).map { day in Double([2, 1, 12, 9, 8, 7, 6][day % 7]) }
        let estimate = try #require(
            CovidController.estimate(from: Self.series(cases, step: 86_400, unit: UnitPopulation.people), selector: .covid(.cases), now: Self.now))
        #expect(estimate.origin == .estimate("weekly pattern"))
        #expect(estimate.points.count == 14)
        #expect(estimate.points.allSatisfy { $0.value.value >= 0 && ($0.lower ?? -1) >= 0 })
        // The pattern carries on: the forecast has a low weekend and a busy start of the week.
        let forecast = estimate.points.map(\.value.value)
        #expect((forecast.max() ?? 0) > 2 * (forecast.min() ?? 0))
        let incidence = (0 ..< 90).map { 20 + 0.2 * Double($0) }
        let trend = try #require(
            CovidController.estimate(
                from: Self.series(incidence, step: 86_400, unit: UnitIncidence.casesPer100k), selector: .covid(.incidence), now: Self.now))
        #expect(trend.origin == .estimate("trend"))
        #expect(CovidController.estimate(from: Self.series(incidence, step: 86_400, age: 30 * 86_400, unit: UnitIncidence.casesPer100k), selector: .covid(.incidence), now: Self.now) == nil)
    }
}
