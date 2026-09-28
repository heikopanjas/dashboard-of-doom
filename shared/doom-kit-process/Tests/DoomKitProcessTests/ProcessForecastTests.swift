import DoomKitLocation
import DoomKitProcess
import Foundation
import Testing

struct ProcessForecastTests {
    private let location = Location(latitude: 52, longitude: 13)
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func point(_ hours: Double, _ value: Double, band: Double? = nil) -> ProcessForecast.Point {
        return ProcessForecast.Point(
            timestamp: self.now.addingTimeInterval(hours * 3600), value: Measurement(value: value, unit: UnitLength.meters),
            lower: band.map { value - $0 }, upper: band.map { value + $0 })
    }

    private func measurement(_ hours: Double, _ value: Double) -> ProcessValue<Dimension> {
        return ProcessValue<Dimension>(value: Measurement(value: value, unit: UnitLength.meters), quality: .good, timestamp: self.now.addingTimeInterval(hours * 3600))
    }

    @Test func pointsAreSortedAndLookedUpWithinATolerance() {
        let forecast = ProcessForecast(origin: .provider("PEGELONLINE"), points: [self.point(2, 1.2), self.point(1, 1.1, band: 0.1)])
        #expect(forecast.points.map(\.value.value) == [1.1, 1.2])
        #expect(forecast.points.first?.hasBand == true)
        #expect(forecast.points.last?.hasBand == false)
        #expect(forecast.point(near: self.now.addingTimeInterval(3600 + 600), tolerance: 900)?.value.value == 1.1)
        #expect(forecast.point(near: self.now.addingTimeInterval(4 * 3600), tolerance: 900) == nil)
        #expect(forecast.points(after: self.now.addingTimeInterval(3600)).map(\.value.value) == [1.2])
    }

    @Test func onlyProvidersAreProviders() {
        #expect(ProcessForecast.Origin.provider("UBA").isProvider == true)
        #expect(ProcessForecast.Origin.estimate("trend").isProvider == false)
    }

    @MainActor @Test func forecastsTravelFromSensorToPresenterAfterTheLastMeasurement() throws {
        let forecast = ProcessForecast(
            origin: .provider("PEGELONLINE"), issued: self.now, points: [self.point(-1, 0.9), self.point(0, 1.0), self.point(1, 1.1), self.point(2, 1.2)],
            customData: ["estimateFrom": self.now.addingTimeInterval(7200)])
        let stale = ProcessForecast(origin: .estimate("trend"), points: [self.point(-2, 0.5)])
        let sensor = ProcessSensor(
            name: "Gauge", location: self.location, placemark: nil, customData: nil,
            measurements: [.water(.level): [self.measurement(-1, 0.95), self.measurement(0, 1.0)]], timestamp: self.now,
            forecasts: [.water(.level): forecast, .water(.discharge): stale])
        let transformer = ProcessTransformer()
        try transformer.renderData(sensor: sensor)
        let rendered = try #require(transformer.forecasts[.water(.level)])
        // The overlap with the measurements is dropped; the measurement at now wins over the forecast point at now.
        #expect(rendered.points.map(\.value.value) == [1.1, 1.2])
        #expect(rendered.origin == .provider("PEGELONLINE"))
        #expect(rendered.issued == self.now)
        #expect(rendered.customData?["estimateFrom"] as? Date == self.now.addingTimeInterval(7200))
        // A forecast with nothing after the series is dropped whole; without measurements for its selector it is kept.
        #expect(transformer.forecasts[.water(.discharge)]?.points.count == 1)
        let reading = ProcessReading(sensor: sensor, transformer: transformer)
        #expect(reading.forecasts[.water(.level)]?.points.count == 2)
        #expect(ProcessReading(sensor: sensor).forecasts.isEmpty == true)
        #expect(ProcessSensor(name: "Plain", location: self.location, measurements: [:], timestamp: nil).forecasts.isEmpty == true)
    }

    @Test func aForecastEntirelyInThePastIsDropped() throws {
        let sensor = ProcessSensor(
            name: "Gauge", location: self.location, placemark: nil, customData: nil, measurements: [.water(.level): [self.measurement(0, 1.0)]],
            timestamp: self.now, forecasts: [.water(.level): ProcessForecast(origin: .estimate("trend"), points: [self.point(-1, 0.9)])])
        let transformer = ProcessTransformer()
        try transformer.renderData(sensor: sensor)
        #expect(transformer.forecasts.isEmpty == true)
    }
}
