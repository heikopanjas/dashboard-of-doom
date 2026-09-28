import Foundation

/// What a series is expected to do after its last measurement. It travels beside the measurements, never inside them, so a chart can draw
/// it differently and the current value, trend and range never read a forecast as if it had been measured.
public struct ProcessForecast {
    /// Who made the forecast. A provider's forecast is the data source's own prediction, published with its data; an estimate is the app's
    /// extrapolation of the measurements, named by its method. Only a provider's forecast may raise a warning.
    public enum Origin: Equatable, Sendable {
        case provider(String)
        case estimate(String)

        public var isProvider: Bool {
            if case .provider = self {
                return true
            }
            return false
        }
    }

    /// One predicted value, with the uncertainty band around it where the forecast has one. `lower` and `upper` are in the unit of `value`.
    public struct Point: Identifiable {
        public var id: Date {
            return self.timestamp
        }

        public let timestamp: Date
        public let value: Measurement<Dimension>
        public let lower: Double?
        public let upper: Double?

        public init(timestamp: Date, value: Measurement<Dimension>, lower: Double? = nil, upper: Double? = nil) {
            self.timestamp = timestamp
            self.value = value
            self.lower = lower
            self.upper = upper
        }

        public var hasBand: Bool {
            return self.lower != nil && self.upper != nil
        }
    }

    public let origin: Origin
    /// When the provider computed the forecast, where it says so.
    public let issued: Date?
    /// Oldest first.
    public let points: [Point]
    /// Anything a single source needs to hand the UI about its forecast, as on `ProcessSensor`.
    public let customData: [String: Any]?

    public init(origin: Origin, issued: Date? = nil, points: [Point], customData: [String: Any]? = nil) {
        self.origin = origin
        self.issued = issued
        self.points = points.sorted { $0.timestamp < $1.timestamp }
        self.customData = customData
    }

    /// The point closest to `date`, if one lies within `tolerance`.
    public func point(near date: Date, tolerance: TimeInterval) -> Point? {
        let nearest = self.points.min { abs($0.timestamp.timeIntervalSince(date)) < abs($1.timestamp.timeIntervalSince(date)) }
        guard let nearest, abs(nearest.timestamp.timeIntervalSince(date)) <= tolerance else { return nil }
        return nearest
    }

    /// The points strictly after `date`.
    public func points(after date: Date) -> [Point] {
        return self.points.filter { $0.timestamp > date }
    }

    /// The same forecast with only the points strictly after `date`, or nil when none are left.
    public func trimmed(after date: Date) -> ProcessForecast? {
        let points = self.points(after: date)
        guard points.isEmpty == false else { return nil }
        return ProcessForecast(origin: self.origin, issued: self.issued, points: points, customData: self.customData)
    }
}
