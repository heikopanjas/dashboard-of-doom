import DoomKitProcess
import Foundation
import Testing

@Suite struct EnergyControllerTests {
    /// The oil-prices project's format, verbatim from the Brent file, oldest first as the file is.
    private static let oil = """
        Date,Price
        2026-09-11,118.06
        2026-09-14,121.25
        2026-09-15,130.8
        """

    /// ACER's export, verbatim: quoted, newest first, and the early rows have no EU price.
    private static let lng = """
        "DATE","NORTH-WEST EUROPE PRICE (EUR/MWh)","SOUTH EUROPE PRICE (EUR/MWh)","EU PRICE (EUR/MWh)","LNG BENCHMARK (EUR/MWh)"
        "2026-09-18","78.404","78.307","78.223","-1.295"
        "2026-09-17","80.669","79.728","80.073","3.721"
        "2023-01-27","54.770","53.080","",""
        """

    private static func utcMidnight(_ text: String) -> Date? {
        return EnergyController.date(from: text)
    }

    @Test func oilRowsBecomeGoodValuesInDollarsPerBarrelOldestFirst() throws {
        let values = EnergyController.parseOil(Data(Self.oil.utf8), unit: UnitOilPrice.usDollarsPerBarrel)
        #expect(values.map { $0.value.value } == [118.06, 121.25, 130.8])
        #expect(values.allSatisfy { $0.value.unit == UnitOilPrice.usDollarsPerBarrel } == true)
        #expect(values.allSatisfy { $0.quality == .good } == true)
        #expect(values.last?.timestamp == Self.utcMidnight("2026-09-15"))
    }

    @Test func lngRowsUseTheEUPriceAndSkipRowsWithout() throws {
        let data = try #require(Self.lng.data(using: .isoLatin1))
        let values = EnergyController.parseLNG(data)
        // Sorted oldest first whatever the file's order, and the 2023 row without an EU price is gone.
        #expect(values.map { $0.value.value } == [80.073, 78.223])
        #expect(values.allSatisfy { $0.value.unit == UnitGasPrice.eurosPerMegawattHour } == true)
        #expect(values.first?.timestamp == Self.utcMidnight("2026-09-17"))
    }

    @Test func datesAreMidnightUTC() throws {
        let date = try #require(Self.utcMidnight("2026-09-15"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        #expect(parts.year == 2026 && parts.month == 9 && parts.day == 15 && parts.hour == 0 && parts.minute == 0)
        // What the chart's drag rounding lands on, so a dragged marker finds the day.
        #expect(Date.round(from: date.addingTimeInterval(5 * 3600), strategy: .lastDayChange) == date)
    }

    @Test func unreadableRowsAreSkipped() {
        let text = "Date,Price\nnot a date,1\n2026-09-15,abc\n2026-09-14,\n\n2026-09-13,99.5\n"
        let values = EnergyController.parseOil(Data(text.utf8), unit: UnitOilPrice.usDollarsPerBarrel)
        #expect(values.map { $0.value.value } == [99.5])
        #expect(EnergyController.parseOil(Data(), unit: UnitOilPrice.usDollarsPerBarrel).isEmpty == true)
        #expect(EnergyController.parseLNG(Data("garbage".utf8)).isEmpty == true)
    }

    @Test func theSeriesFillsClosedDaysAndKeepsOnlyTheSpan() throws {
        // Friday, then the next Monday: the weekend has no prices.
        let friday = try #require(Self.utcMidnight("2026-09-11"))
        let monday = try #require(Self.utcMidnight("2026-09-14"))
        let old = try #require(Self.utcMidnight("2025-01-05"))
        let value = { (price: Double, date: Date) in
            return ProcessValue<Dimension>(value: Measurement(value: price, unit: UnitOilPrice.usDollarsPerBarrel), quality: .good, timestamp: date)
        }
        let now = monday.addingTimeInterval(36 * 3600)
        let series = EnergyController.series([value(1, old), value(118, friday), value(121, monday)], until: now)
        #expect(series.map { $0.value.value } == [118, 118, 118, 121])
        #expect(series.map { $0.quality } == [.good, .uncertain, .uncertain, .good])
        #expect(series.first?.timestamp == friday)
        #expect(series.last?.timestamp == monday)
        #expect(series[1].timestamp == friday.addingTimeInterval(24 * 3600))
        // The old price is outside the year and gone; nothing at all gives nothing.
        #expect(EnergyController.series([value(1, old)], until: now).isEmpty == true)
        #expect(EnergyController.series([], until: now).isEmpty == true)
    }

    @Test func thePricesOfAYearFitTheChartWithRoom() throws {
        let transformer = EnergyTransformer()
        let date = try #require(Self.utcMidnight("2026-09-15"))
        let values = [100.0, 120.0].map { price in
            return ProcessValue<Dimension>(value: Measurement(value: price, unit: UnitOilPrice.usDollarsPerBarrel), quality: .good, timestamp: date)
        }
        let range = try #require(transformer.renderRange(measurements: [.energy(.brent): values])[.energy(.brent)])
        #expect(abs(range.lowerBound - 98) < 0.001)
        #expect(abs(range.upperBound - 122.4) < 0.001)
        let faceplate = transformer.renderFaceplate(current: [.energy(.brent): values[1]])
        #expect(faceplate[.energy(.brent)] == "120.00 USD/bbl")
    }
}
