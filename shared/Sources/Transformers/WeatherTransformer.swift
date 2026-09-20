import DoomKitTools
import DoomKitProcess
import Foundation

class WeatherTransformer: ProcessTransformer {
    override func renderCurrent(measurements: [ProcessSelector: [ProcessValue<Dimension>]]) -> [ProcessSelector: ProcessValue<Dimension>] {
        var current: [ProcessSelector: ProcessValue<Dimension>] = [:]
        for (selector, measurement) in measurements {
            current[selector] = measurement.first
        }
        return current
    }

    override func renderFaceplate(current: [ProcessSelector: ProcessValue<Dimension>]) -> [ProcessSelector: String] {
        var faceplate: [ProcessSelector: String] = [:]
        for (selector, current) in current {
            faceplate[selector] = String(format: "\(MathematicalSymbols.mathematicalBoldCapitalTau.rawValue): %.1f%@", current.value.value, current.value.unit.symbol)
        }
        return faceplate
    }

    override func renderRange(measurements: [ProcessSelector: [ProcessValue<Dimension>]]) -> [ProcessSelector: ClosedRange<Double>] {
        var range: [ProcessSelector: ClosedRange<Double>] = [:]
        for (selector, _) in measurements {
            range[selector] = 0.0 ... 0.0
        }
        return range
    }

    override func renderTrend(measurements: [ProcessSelector: [ProcessValue<Dimension>]]) -> [ProcessSelector: String] {
        var trend: [ProcessSelector: String] = [:]
        for (selector, _) in measurements {
            trend[selector] = "questionmark.circle"
        }
        return trend
    }
}
