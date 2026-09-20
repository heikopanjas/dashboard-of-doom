import Foundation

public class UnitPopulation: Dimension, @unchecked Sendable {
    public static let people = UnitPopulation(
        symbol: "n",
        converter: UnitConverterLinear(coefficient: 1.0)
    )

    public static let thousand = UnitPopulation(
        symbol: "k",
        converter: UnitConverterLinear(coefficient: 1000.0)
    )

    public static let million = UnitPopulation(
        symbol: "M",
        converter: UnitConverterLinear(coefficient: 1000000.0)
    )

    public override class func baseUnit() -> Self {
        return Self.people as! Self
    }
}
