import Foundation

public class UnitTurbidity: Dimension, @unchecked Sendable {
    public static let fnu = UnitTurbidity(
        symbol: "FNU",
        converter: UnitConverterLinear(coefficient: 1.0) // FNU as base unit
    )

    // If you plan to add NTU later, choose a consistent base unit (e.g., FNU or NTU)
    public override class func baseUnit() -> Self {
        return Self.fnu as! Self
    }
}
