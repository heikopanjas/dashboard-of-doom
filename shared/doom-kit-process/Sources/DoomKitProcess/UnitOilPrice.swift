import Foundation

/// The price of crude oil. A single unit: a price in one currency per barrel does not convert into anything else.
public class UnitOilPrice: Dimension, @unchecked Sendable {
    public static let usDollarsPerBarrel = UnitOilPrice(
        symbol: "USD/bbl",
        converter: UnitConverterLinear(coefficient: 1.0)
    )
    public override class func baseUnit() -> Self {
        return Self.usDollarsPerBarrel as! Self
    }
}
