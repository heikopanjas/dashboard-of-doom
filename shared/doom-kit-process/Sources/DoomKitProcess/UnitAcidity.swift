import Foundation

public class UnitAcidity: Dimension, @unchecked Sendable {
    public static let pH = UnitAcidity(
        symbol: "pH",
        converter: UnitConverterLinear(coefficient: 1.0) // dimensionless
    )

    public override class func baseUnit() -> Self {
        return Self.pH as! Self
    }
}
