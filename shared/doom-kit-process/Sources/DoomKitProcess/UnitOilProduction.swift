import Foundation

/// How much oil a country produces. A single unit: production in barrels a day does not convert into anything the app shows otherwise.
public class UnitOilProduction: Dimension, @unchecked Sendable {
    public static let millionBarrelsPerDay = UnitOilProduction(
        symbol: "mb/d",
        converter: UnitConverterLinear(coefficient: 1.0)
    )
    public override class func baseUnit() -> Self {
        // swift-format-ignore: NeverForceUnwrap
        return Self.millionBarrelsPerDay as! Self
    }
}
