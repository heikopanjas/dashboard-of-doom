import Foundation
import Testing

@Suite struct LevelRangeTests {
    @Test func anOrdinaryLevelStartsAtZeroWithRoomAbove() {
        let range = LevelTransformer.range([1.8, 2.02])
        #expect(range.lowerBound == 0)
        #expect(abs(range.upperBound - 2.02 * 1.67) < 0.000_001)
    }

    @Test func aLevelBelowItsGaugeZeroStaysInsideTheRange() {
        // Lahnstein Schleuse UP swinging around its zero, and the Rhine at Koblenz at low water.
        let lahn = LevelTransformer.range([-0.06, 0.0, 0.06])
        #expect(lahn.lowerBound == -0.06)
        #expect(lahn.upperBound > 0.06)
        let rhine = LevelTransformer.range([-0.10, -0.04, -0.02])
        #expect(rhine.lowerBound == -0.10)
        #expect(rhine.upperBound > -0.02)
        #expect(rhine.upperBound > rhine.lowerBound)
    }

    @Test func aFlatZeroLevelStillHasARange() {
        let flat = LevelTransformer.range([0, 0, 0])
        #expect(flat.upperBound > flat.lowerBound)
        #expect(LevelTransformer.range([]) == 0 ... 0)
    }
}
