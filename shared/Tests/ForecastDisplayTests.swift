import DoomKitProcess
import Foundation
import Testing

@Suite struct ForecastDisplayTests {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    private func forecast(_ values: [Double], step: TimeInterval = 3600, band: Double? = nil, origin: ProcessForecast.Origin = .provider("UBA")) -> ProcessForecast {
        let points = values.enumerated().map { index, value in
            ProcessForecast.Point(
                timestamp: self.start.addingTimeInterval(Double(index + 1) * step), value: Measurement(value: value, unit: UnitLength.meters),
                lower: band.map { value - $0 }, upper: band.map { value + $0 })
        }
        return ProcessForecast(origin: origin, points: points)
    }

    @Test func labelsSayWhoseForecastItIs() {
        #expect(ForecastDisplay.label(for: .provider("UBA")) == "Forecast · UBA")
        #expect(ForecastDisplay.label(for: .estimate("trend")) == "Estimate · trend")
        #expect(ForecastDisplay.legend(for: .provider("PEGELONLINE")) == "PEGELONLINE forecast")
        #expect(ForecastDisplay.legend(for: .estimate("usual range")) == "App estimate (usual range)")
    }

    @Test func theDomainGrowsToHoldTheForecastAndItsBand() {
        #expect(ForecastDisplay.domain(range: 0 ... 5, forecast: nil) == 0 ... 5)
        #expect(ForecastDisplay.domain(range: nil, forecast: nil) == 0 ... 0)
        #expect(ForecastDisplay.domain(range: 0 ... 5, forecast: self.forecast([4, 6])) == 0 ... 6)
        #expect(ForecastDisplay.domain(range: 2 ... 5, forecast: self.forecast([3, 4], band: 1.5)) == 1.5 ... 5.5)
        #expect(ForecastDisplay.domain(range: 0 ... 5, forecast: self.forecast([])) == 0 ... 5)
    }

    @Test func theMarkerFindsTheNearestPointWithinHalfTheSpacing() {
        let hourly = self.forecast([1, 2, 3])
        #expect(ForecastDisplay.tolerance(for: hourly) == 1800)
        // A quarter-hour drag lands on the hourly point it is closest to.
        #expect(ForecastDisplay.point(at: self.start.addingTimeInterval(3600 + 900), in: hourly)?.value.value == 1)
        #expect(ForecastDisplay.point(at: self.start.addingTimeInterval(2 * 3600 - 900), in: hourly)?.value.value == 2)
        // Beyond the last point by more than the tolerance there is nothing to show.
        #expect(ForecastDisplay.point(at: self.start.addingTimeInterval(5 * 3600), in: hourly) == nil)
        #expect(ForecastDisplay.point(at: self.start, in: nil) == nil)
        #expect(ForecastDisplay.tolerance(for: self.forecast([1])) == 3600)
        #expect(ForecastDisplay.tolerance(for: self.forecast([1, 2], step: 60)) == 60)
    }
}
