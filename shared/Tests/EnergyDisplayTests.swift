import DoomKitProcess
import Foundation
import Testing

@Suite struct EnergyDisplayTests {
    private static let day: TimeInterval = 24 * 3600
    private static let start = Date(timeIntervalSince1970: 1_790_000_000)

    private static func series(count: Int, step: TimeInterval) -> [ProcessValue<Dimension>] {
        return (0 ..< count).map { index in
            return ProcessValue<Dimension>(
                value: Measurement(value: Double(index), unit: UnitSupplyDays.days), quality: .good,
                timestamp: Self.start.addingTimeInterval(Double(index) * step))
        }
    }

    @Test func aDailySeriesLandsOnTheDraggedDay() {
        let values = Self.series(count: 10, step: Self.day)
        #expect(EnergyDisplay.measurement(at: Self.start.addingTimeInterval(4 * Self.day), in: values)?.value.value == 4)
        // Half a day past the last value is still the last; beyond that the forecast takes over.
        #expect(EnergyDisplay.measurement(at: Self.start.addingTimeInterval(9.4 * Self.day), in: values)?.value.value == 9)
        #expect(EnergyDisplay.measurement(at: Self.start.addingTimeInterval(10 * Self.day), in: values) == nil)
    }

    @Test func aMonthlySeriesIsFoundFromAnyDayNearItsMonth() {
        let values = Self.series(count: 6, step: 30 * Self.day)
        #expect(EnergyDisplay.measurement(at: Self.start.addingTimeInterval(41 * Self.day), in: values)?.value.value == 1)
        #expect(EnergyDisplay.measurement(at: Self.start.addingTimeInterval(49 * Self.day), in: values)?.value.value == 2)
        #expect(EnergyDisplay.measurement(at: Self.start.addingTimeInterval(-14 * Self.day), in: values)?.value.value == 0)
        #expect(EnergyDisplay.measurement(at: Self.start.addingTimeInterval(-16 * Self.day), in: values) == nil)
    }

    @Test func nothingIsFoundInNothing() {
        #expect(EnergyDisplay.measurement(at: Self.start, in: []) == nil)
        #expect(EnergyDisplay.measurement(at: Self.start, in: Self.series(count: 1, step: Self.day))?.value.value == 0)
    }
}
