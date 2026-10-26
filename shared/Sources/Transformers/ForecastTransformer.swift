import DoomKitProcess
import Foundation

class ForecastTransformer: ProcessTransformer {
    override func renderCurrent(measurements: [ProcessSelector: [ProcessValue<Dimension>]]) -> [ProcessSelector: ProcessValue<Dimension>] {
        var current: [ProcessSelector: ProcessValue<Dimension>] = [:]
        for (selector, measurement) in measurements {
            current[selector] = measurement.last(where: { $0.timestamp == Date.round(from: Date.now, strategy: .nextHour) })
        }
        return current
    }

    override func renderRange(measurements: [ProcessSelector: [ProcessValue<Dimension>]]) -> [ProcessSelector: ClosedRange<Double>] {
        var range: [ProcessSelector: ClosedRange<Double>] = [:]
        for (selector, measurement) in measurements {
            if let value = measurement.first {
                if value.value.unit is UnitTemperature {
                    range[selector] = -33.0 ... 47.0
                }
                else if value.value.unit is UnitPercentage {
                    range[selector] = 0.0 ... 100.0
                }
                else {
                    range[selector] = (measurement.map({ $0.value }).min()?.value ?? 0.0) ... (measurement.map({ $0.value }).max()?.value ?? 0.0)
                }
            }
        }
        return range
    }

    override func renderTrend(measurements: [ProcessSelector: [ProcessValue<Dimension>]]) -> [ProcessSelector: String] {
        var trend: [ProcessSelector: String] = [:]
        for (selector, values) in measurements {
            trend[selector] = "questionmark.circle"
            if let next = values.first(where: { $0.timestamp > Date.now }) {
                if let past = values.last(where: { $0.timestamp <= next.timestamp }) {
                    if past.value < next.value {
                        trend[selector] = "arrow.up.forward.circle"
                    }
                    else if past.value > next.value {
                        trend[selector] = "arrow.down.forward.circle"
                    }
                    else {
                        trend[selector] = "arrow.right.circle"
                    }
                }
            }
        }
        return trend
    }
}
