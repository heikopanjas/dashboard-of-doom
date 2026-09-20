import DoomKitLocation
import Foundation
import Observation

@MainActor @Observable open class ProcessPresenter {
    public nonisolated let id = UUID()

    /// Rendered sensors, nearest first. Everything below reads the first element, so a consumer that only wants the nearest sensor never
    /// has to know there are more.
    public private(set) var readings: [ProcessReading] = []

    @ObservationIgnored private weak var coordinator: ProcessCoordinator?

    public init(coordinator: ProcessCoordinator? = nil) {
        self.coordinator = coordinator
    }

    isolated deinit {
        self.coordinator?.remove(id: self.id)
    }

    public var sensor: ProcessSensor? {
        return self.readings.first?.sensor
    }

    public var measurements: [ProcessSelector: [ProcessValue<Dimension>]] {
        return self.readings.first?.measurements ?? [:]
    }

    public var timestamp: Date? {
        return self.readings.first?.sensor.timestamp
    }

    public var current: [ProcessSelector: ProcessValue<Dimension>] {
        return self.readings.first?.current ?? [:]
    }

    public var faceplate: [ProcessSelector: String] {
        return self.readings.first?.faceplate ?? [:]
    }

    public var range: [ProcessSelector: ClosedRange<Double>] {
        return self.readings.first?.range ?? [:]
    }

    public var trend: [ProcessSelector: String] {
        return self.readings.first?.trend ?? [:]
    }

    /// Publishes the readings of a refresh. An empty array is ignored, so a failed or cancelled refresh keeps the last good values.
    public func publish(readings: [ProcessReading]) -> Void {
        guard readings.isEmpty == false else { return }
        self.readings = readings
    }

    /// Replaces the readings unconditionally, including with none. For fixtures and tests; refresh paths use `publish(readings:)`.
    public func replace(readings: [ProcessReading]) -> Void {
        self.readings = readings
    }

    public var label: String {
        if let customData = self.sensor?.customData {
            if let label = customData["label"] as? String {
                return label
            }
        }
        return "<Unknown>"
    }

    public var icon: String {
        if let customData = self.sensor?.customData {
            if let icon = customData["icon"] as? String {
                return icon
            }
        }
        return "questionmark.circle"
    }

    public var name: String {
        return self.sensor?.name ?? "<Unknown>"
    }

    public var location: Location {
        return self.sensor?.location ?? Location(latitude: 0.0, longitude: 0.0)
    }

    public var placemark: String {
        return self.sensor?.placemark ?? "<Unknown>"
    }

    /// Whether the nearest sensor has data for `selector`; see `ProcessReading.isAvailable(selector:treshold:)`.
    public func isAvailable(selector: ProcessSelector, treshold: Double = 0.0) -> Bool {
        return self.readings.first?.isAvailable(selector: selector, treshold: treshold) ?? false
    }
}
