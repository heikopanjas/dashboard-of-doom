import DoomKitTools
import DoomKitProcess
import Foundation

class CovidTransformer: ProcessTransformer {
    override func renderCurrent(measurements: [ProcessSelector: [ProcessValue<Dimension>]]) -> [ProcessSelector: ProcessValue<Dimension>] {
        var current: [ProcessSelector: ProcessValue<Dimension>] = [:]
        for (selector, values) in measurements {
            current[selector] = values.last(where: { ($0.timestamp <= Date.now) && (($0.quality == .good) || ($0.quality == .uncertain))})
        }
        return current
    }

    override func renderFaceplate(current: [ProcessSelector: ProcessValue<Dimension>]) -> [ProcessSelector: String] {
        var faceplate: [ProcessSelector: String] = [:]
        for (selector, current) in self.current {
            switch selector {
                case .covid(.incidence):
                    faceplate[selector] = String(
                        format: "\(MathematicalSymbols.mathematicalBoldCapitalOmicron.rawValue)%@: %.1f",
                        current.value.unit.symbol, current.value.value)
                default:
                    faceplate[selector] = String(
                        format: "\(MathematicalSymbols.mathematicalBoldCapitalOmicron.rawValue): %.0f%@", current.value.value,
                        current.value.unit.symbol)
            }
        }
        return faceplate
    }

    override func renderRange(measurements: [ProcessSelector: [ProcessValue<Dimension>]]) -> [ProcessSelector: ClosedRange<Double>] {
        var scale: [ProcessSelector: ClosedRange<Double>] = [:]
        for (selector, values) in measurements {
            scale[selector] = (values.map({ $0.value }).min()?.value ?? 0.0) ... (values.map({ $0.value }).max()?.value ?? 0.0) * 1.33
        }
        return scale
    }
}
