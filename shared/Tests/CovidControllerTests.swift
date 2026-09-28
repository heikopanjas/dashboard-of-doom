import DoomKitProcess
import Foundation
import Testing

@Suite struct CovidControllerTests {
    private static func value(_ value: Double, day: Int) -> ProcessValue<Dimension> {
        return ProcessValue<Dimension>(
            value: Measurement(value: value, unit: UnitIncidence.casesPer100k), quality: .good,
            timestamp: Date(timeIntervalSince1970: 1_800_000_000 + Double(day) * 86_400))
    }

    @Test func aSingleReportHasNothingToBlend() {
        // It used to read the second value of a series of one and crash.
        #expect(CovidController.nowCast(data: [Self.value(10, day: 0)], alpha: 0.33) == nil)
        #expect(CovidController.nowCast(data: [], alpha: 0.33) == nil)
        #expect(CovidController.nowCast(data: nil, alpha: 0.33) == nil)
    }

    @Test func twoReportsBlendIntoTheNextDay() throws {
        let nowCast = try #require(CovidController.nowCast(data: [Self.value(10, day: 0), Self.value(20, day: 1)], alpha: 0.33))
        #expect(nowCast.quality == .uncertain)
        #expect(nowCast.timestamp == Date(timeIntervalSince1970: 1_800_000_000 + 2 * 86_400))
        #expect(abs(nowCast.value.value - (0.33 * 10 + 0.67 * 20)) < 0.000_001)
    }
}
