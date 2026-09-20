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
            scale[selector] = 0.0 ... (values.map({ $0.value }).max()?.value ?? 0.0) * 1.67
        }
        return scale
    }
}
