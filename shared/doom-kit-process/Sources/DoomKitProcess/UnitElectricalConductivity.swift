import Foundation

public class UnitElectricalConductivity: Dimension, @unchecked Sendable {
    public static let millisiemensPerCentimeter = UnitElectricalConductivity(
        symbol: "mS/cm",
        converter: UnitConverterLinear(coefficient: 0.1) // 1 mS/cm = 0.1 S/m
    )

    public static let siemensPerMeter = UnitElectricalConductivity(
        symbol: "S/m",
        converter: UnitConverterLinear(coefficient: 1.0)
    )

    // Base unit is millisiemensPerCentimeter (mS/cm)
    public override class func baseUnit() -> Self {
        return Self.millisiemensPerCentimeter as! Self
    }
}
