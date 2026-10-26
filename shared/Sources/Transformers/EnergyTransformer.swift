import DoomKitProcess
import Foundation

class EnergyTransformer: ProcessTransformer {
    /// A space before the unit, since these are words such as `USD/bbl` or `days` rather than symbols.
    override func renderFaceplate(current: [ProcessSelector: ProcessValue<Dimension>]) -> [ProcessSelector: String] {
        var faceplate: [ProcessSelector: String] = [:]
        for (selector, current) in current {
            faceplate[selector] = EnergyDisplay.valueText(current, for: selector)
        }
        return faceplate
    }

    /// Two percent of room above and below the year's prices, so their movement fills the chart rather than sitting on a zero axis. A stock's
    /// range also holds its minimum, so the line drawn there is always on the chart.
    override func renderRange(measurements: [ProcessSelector: [ProcessValue<Dimension>]]) -> [ProcessSelector: ClosedRange<Double>] {
        var range: [ProcessSelector: ClosedRange<Double>] = [:]
        for (selector, values) in measurements {
            let prices = values.map { $0.value.value } + [EnergyDisplay.minimumDays(in: values)].compactMap { $0 }
            if let low = prices.min(), let high = prices.max() {
                range[selector] = (low * 0.98) ... max(high * 1.02, low * 0.98 + 1)
            }
        }
        return range
    }
}
