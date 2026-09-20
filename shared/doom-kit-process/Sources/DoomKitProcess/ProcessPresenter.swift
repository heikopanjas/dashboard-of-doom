import DoomKitLocation
import Foundation
import Observation

@MainActor @Observable open class ProcessPresenter {
    public nonisolated let id = UUID()
    public var sensor: ProcessSensor?
    public var measurements: [ProcessSelector: [ProcessValue<Dimension>]] = [:]
    public var timestamp: Date? = nil

    public var current: [ProcessSelector: ProcessValue<Dimension>] = [:]
    public var faceplate: [ProcessSelector: String] = [:]
    public var range: [ProcessSelector: ClosedRange<Double>] = [:]
    public var trend: [ProcessSelector: String] = [:]

    @ObservationIgnored private weak var coordinator: ProcessCoordinator?

    public init(coordinator: ProcessCoordinator? = nil) {
        self.coordinator = coordinator
    }

    isolated deinit {
        self.coordinator?.remove(id: self.id)
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
}
