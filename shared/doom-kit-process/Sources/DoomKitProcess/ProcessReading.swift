import Foundation

/// One sensor together with everything its transformer rendered for it.
public struct ProcessReading: Identifiable {
    public let sensor: ProcessSensor
    public let measurements: [ProcessSelector: [ProcessValue<Dimension>]]
    public let current: [ProcessSelector: ProcessValue<Dimension>]
    public let faceplate: [ProcessSelector: String]
    public let range: [ProcessSelector: ClosedRange<Double>]
    public let trend: [ProcessSelector: String]

    /// The sensor's source id, which survives a refresh, so a list of readings keeps its identity. A sensor without one falls back to its
    /// own id, which changes with every refresh.
    public var id: String {
        return self.sensor.sourceID ?? self.sensor.id.uuidString
    }

    /// Whether the series for `selector` has a real value above `treshold`. Values of unknown quality do not count.
    public func isAvailable(selector: ProcessSelector, treshold: Double = 0.0) -> Bool {
        if let measurements = self.measurements[selector] {
            if measurements.count > 0 {
                for measurement in measurements where measurement.quality != .unknown {
                    if measurement.value.value > treshold {
                        return true
                    }
                }
            }
        }
        return false
    }

    public init(sensor: ProcessSensor, transformer: ProcessTransformer) {
        self.sensor = sensor
        self.measurements = transformer.measurements
        self.current = transformer.current
        self.faceplate = transformer.faceplate
        self.range = transformer.range
        self.trend = transformer.trend
    }

    /// Renders every sensor with its own transformer, keeping the order of `sensors`.
    public static func render(sensors: [ProcessSensor], transformer makeTransformer: () -> ProcessTransformer) throws -> [ProcessReading] {
        return try sensors.map { sensor in
            let transformer = makeTransformer()
            try transformer.renderData(sensor: sensor)
            return ProcessReading(sensor: sensor, transformer: transformer)
        }
    }

    public init(
        sensor: ProcessSensor,
        measurements: [ProcessSelector: [ProcessValue<Dimension>]] = [:],
        current: [ProcessSelector: ProcessValue<Dimension>] = [:],
        faceplate: [ProcessSelector: String] = [:],
        range: [ProcessSelector: ClosedRange<Double>] = [:],
        trend: [ProcessSelector: String] = [:]
    ) {
        self.sensor = sensor
        self.measurements = measurements
        self.current = current
        self.faceplate = faceplate
        self.range = range
        self.trend = trend
    }
}
