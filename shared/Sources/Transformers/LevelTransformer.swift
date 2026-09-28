import DoomKitTools
import DoomKitProcess
import Foundation

class LevelTransformer: ProcessTransformer {
    override func renderFaceplate(current: [ProcessSelector: ProcessValue<Dimension>]) -> [ProcessSelector: String] {
        var faceplate: [ProcessSelector: String] = [:]
        for (selector, current) in current {
            switch selector {
                case .water:
                    faceplate[selector] = String(
                        format: "\(MathematicalSymbols.mathematicalBoldCapitalEta.rawValue): %.2f%@", current.value.value,
                        current.value.unit.symbol)
                default:
                    faceplate[selector] = "\(MathematicalSymbols.mathematicalItalicCapitalEta.rawValue):n/a"
            }
        }
        return faceplate
    }

    override func renderRange(measurements: [ProcessSelector: [ProcessValue<Dimension>]]) -> [ProcessSelector: ClosedRange<Double>] {
        var scale: [ProcessSelector: ClosedRange<Double>] = [:]
        for (selector, values) in measurements {
            scale[selector] = Self.range(values.map(\.value.value))
        }
        return scale
    }

    /// From zero, or from the lowest value when the level falls below its gauge zero, to two thirds above the highest. A level at or
    /// below zero is ordinary at low water (the Rhine at Koblenz stood at −4 cm in September 2026); a range pinned to zero drew such
    /// values below the plot, over the axis labels, and a highest value at or below zero left no range at all.
    static func range(_ values: [Double]) -> ClosedRange<Double> {
        guard let low = values.min(), let high = values.max() else { return 0.0 ... 0.0 }
        let lower = min(0, low)
        let upper = max(high * 1.67, high + (high - lower) * 0.67, lower + 0.1)
        return lower ... upper
    }
}
