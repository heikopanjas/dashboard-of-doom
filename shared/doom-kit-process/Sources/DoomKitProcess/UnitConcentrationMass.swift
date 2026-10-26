import Foundation

extension UnitConcentrationMass {
    public static let microgramsPerCubicMeter = UnitConcentrationMass(
        symbol: "µg/m³",
        converter: UnitConverterLinear(coefficient: 0.000001)  // 1 µg/m³ = 0.000001 g/L
    )

    public static let milligramsPerCubicMeter = UnitConcentrationMass(
        symbol: "mg/m³",
        converter: UnitConverterLinear(coefficient: 0.001)  // 1 mg/m³ = 0.001 g/L
    )

    public static let nanogramsPerCubicMeter = UnitConcentrationMass(
        symbol: "ng/m³",
        converter: UnitConverterLinear(coefficient: 0.000000001)  // 1 ng/m³ = 0.000000001 g/L
    )
}
