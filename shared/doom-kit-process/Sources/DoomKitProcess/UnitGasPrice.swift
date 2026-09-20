import Foundation

/// The price of natural gas, as Europe quotes it: euros per megawatt hour of energy delivered. A single unit, and a dimension of its own,
/// since it does not convert into an oil price.
public class UnitGasPrice: Dimension, @unchecked Sendable {
    public static let eurosPerMegawattHour = UnitGasPrice(
        symbol: "EUR/MWh",
        converter: UnitConverterLinear(coefficient: 1.0)
    )
    public override class func baseUnit() -> Self {
        return Self.eurosPerMegawattHour as! Self
    }
}
