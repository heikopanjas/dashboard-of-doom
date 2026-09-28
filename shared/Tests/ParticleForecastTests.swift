import DoomKitLocation
import DoomKitProcess
import Foundation
import Testing

@Suite struct ParticleForecastTests {
    /// Two hours of a UBA forecast for one station, as the service sends it: PM10 (1), ozone (3), NO2 (5) and PM2.5 (9).
    private static let forecast = #"""
        {"data":{"121":{
        "2026-09-28 16:00:00":["2026-09-28 17:00:00","2026-09-28 12:25:00",5,1,[1,8,0,"0.400"],[3,86,1,"1.424"],[5,10,0,"0.500"],[9,3,0,"0.600"]],
        "2026-09-28 15:00:00":["2026-09-28 16:00:00","2026-09-28 12:25:00",5,1,[1,9,0,"0.450"],[3,84,1,"1.400"],[5,11,0,"0.550"],[9,4,0,"0.700"]]
        }}}
        """#

    private final class Calls: @unchecked Sendable {
        private let lock = NSLock()
        private var count = 0

        var value: Int {
            self.lock.lock()
            defer { self.lock.unlock() }
            return self.count
        }

        func record() {
            self.lock.lock()
            self.count += 1
            self.lock.unlock()
        }
    }

    private static func cet(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(secondsFromGMT: 3600)
        return formatter.date(from: string)
    }

    /// Hourly PM10 and NO2 values ending at `end`, with the hour before last missing, so the gap fill shows.
    private static func result(end: Date) -> ParticleController.StationResult {
        let unit = UnitConcentrationMass.microgramsPerCubicMeter
        let values = [-4.0, -3.0, -1.0, 0.0].map { hours in
            ProcessValue<Dimension>(value: Measurement(value: 10 + hours, unit: unit), quality: .good, timestamp: end.addingTimeInterval(hours * 3600))
        }
        return ParticleController.StationResult(
            station: ParticleController.Station(id: "121", code: "DEBE010", name: "Berlin Wedding", location: Location(latitude: 52.54, longitude: 13.35)),
            cachedMeasurements: [.particle(.pm10): values, .particle(.no2): values])
    }

    @Test func aForecastParsesIntoOneProviderForecastPerPollutantInCET() throws {
        let forecasts = try ParticleController.parseForecasts(data: Data(Self.forecast.utf8))
        #expect(Set(forecasts.keys) == [.particle(.pm10), .particle(.o3), .particle(.no2), .particle(.pm25)])
        let pm10 = try #require(forecasts[.particle(.pm10)])
        #expect(pm10.origin == .provider("UBA"))
        #expect(pm10.issued == Self.cet("2026-09-28 12:25:00"))
        // Oldest first, stamped at the end of each hour, which UBA writes in CET: 17:00 CET is 16:00 UTC.
        #expect(pm10.points.map(\.value.value) == [9, 8])
        #expect(pm10.points.last?.timestamp == Date(timeIntervalSince1970: 1_790_611_200))
        #expect(pm10.points.last?.timestamp == Self.cet("2026-09-28 17:00:00"))
        #expect(pm10.points.first?.value.unit == UnitConcentrationMass.microgramsPerCubicMeter)
    }

    @Test func somethingThatIsNotAForecastParsesToNothing() throws {
        #expect(try ParticleController.parseForecasts(data: Data(#"{"data":{}}"#.utf8)).isEmpty == true)
        #expect(try ParticleController.parseForecasts(data: Data("[]".utf8)).isEmpty == true)
    }

    @Test func theForecastTravelsBesideTheMeasurementsForPollutantsTheStationMeasures() async throws {
        let calls = Calls()
        let controller = ParticleController(showForecasts: { true }, fetchForecast: { _, _, _ in
            calls.record()
            return Data(Self.forecast.utf8)
        })
        let end = Date(timeIntervalSince1970: (Date.now.timeIntervalSince1970 / 3600).rounded(.down) * 3600)
        let candidate = try #require(try await controller.candidate(for: Self.result(end: end), from: end.addingTimeInterval(-86_400), to: end))
        #expect(calls.value == 1)
        // Only PM10 and NO2 are measured here, so ozone and PM2.5 have no chart to go on.
        #expect(Set(candidate.forecasts.keys) == [.particle(.pm10), .particle(.no2)])
        #expect(candidate.forecasts[.particle(.pm10)]?.origin.isProvider == true)
        // The forecast is not appended to the series any more; the missing hour is filled.
        #expect(candidate.measurements[.particle(.pm10)]?.count == 5)
        #expect(candidate.measurements[.particle(.pm10)]?.last?.timestamp == end)
    }

    @Test func withForecastsSwitchedOffNothingIsRequested() async throws {
        let calls = Calls()
        let controller = ParticleController(showForecasts: { false }, fetchForecast: { _, _, _ in
            calls.record()
            return Data(Self.forecast.utf8)
        })
        let end = Date(timeIntervalSince1970: (Date.now.timeIntervalSince1970 / 3600).rounded(.down) * 3600)
        let candidate = try #require(try await controller.candidate(for: Self.result(end: end), from: end.addingTimeInterval(-86_400), to: end))
        #expect(calls.value == 0)
        #expect(candidate.forecasts.isEmpty == true)
        #expect(candidate.measurements[.particle(.pm10)]?.count == 5)
    }

    @Test func aFailedForecastCostsOnlyTheForecast() async throws {
        struct Failure: Error {}
        let controller = ParticleController(showForecasts: { true }, fetchForecast: { _, _, _ in throw Failure() })
        let end = Date(timeIntervalSince1970: (Date.now.timeIntervalSince1970 / 3600).rounded(.down) * 3600)
        let candidate = try #require(try await controller.candidate(for: Self.result(end: end), from: end.addingTimeInterval(-86_400), to: end))
        #expect(candidate.forecasts.isEmpty == true)
        // Measurements are gap-filled and smoothed all the same; they used to come out raw when the forecast failed.
        let series = try #require(candidate.measurements[.particle(.pm10)])
        #expect(series.count == 5)
        #expect(series.contains { $0.quality == .uncertain } == true)
    }
}
