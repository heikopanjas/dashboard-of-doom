import Foundation

/// How long a stock lasts at the current rate of consumption. A single unit: days of supply of one fuel do not convert into anything else.
public class UnitSupplyDays: Dimension, @unchecked Sendable {
    public static let days = UnitSupplyDays(
        symbol: "days",
        converter: UnitConverterLinear(coefficient: 1.0)
    )
    public override class func baseUnit() -> Self {
        // swift-format-ignore: NeverForceUnwrap
        return Self.days as! Self
    }
}
