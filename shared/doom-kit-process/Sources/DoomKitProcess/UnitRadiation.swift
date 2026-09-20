import Foundation

public class UnitRadiation: Dimension, @unchecked Sendable {
    public static let sieverts = UnitRadiation(
        symbol: "Sv/h",
        converter: UnitConverterLinear(coefficient: 1.0)
    )

    public static let millisieverts = UnitRadiation(
        symbol: "mSv/h",
        converter: UnitConverterLinear(coefficient: 0.001)
    )

    public static let microsieverts = UnitRadiation(
        symbol: "µSv/h",
        converter: UnitConverterLinear(coefficient: 0.000001)
    )

    public static let grays = UnitRadiation(
        symbol: "Gy/h",
        converter: UnitConverterLinear(coefficient: 1.0)
    )  // Optional: Gray unit

    public override class func baseUnit() -> Self {
        return Self.sieverts as! Self
    }
}
