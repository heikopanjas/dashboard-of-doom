import DoomKitTools
import DoomKitProcess
import Foundation

class RadiationTransformer: ProcessTransformer {
    override func renderFaceplate(current: [ProcessSelector: ProcessValue<Dimension>]) -> [ProcessSelector: String] {
        var faceplate: [ProcessSelector: String] = [:]
        for (selector, current) in current {
            switch selector {
                case .radiation:
                    faceplate[selector] = String(
                        format: "\(MathematicalSymbols.mathematicalBoldCapitalGamma.rawValue): %.3f%@", current.value.value,
                        current.value.unit.symbol)
                default:
                    faceplate[selector] = "\(MathematicalSymbols.mathematicalBoldCapitalGamma.rawValue):n/a"
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
