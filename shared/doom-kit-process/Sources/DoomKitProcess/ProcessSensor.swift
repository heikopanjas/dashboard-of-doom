import DoomKitLocation
import Foundation

public class ProcessSensor: Identifiable {
    public let id = UUID()
    public let name: String
    public let location: Location
    public let placemark: String?
    public let customData: [String: Any]?
    public let measurements: [ProcessSelector: [ProcessValue<Dimension>]]
    public let timestamp: Date?

    public init(name: String, location: Location, measurements: [ProcessSelector: [ProcessValue<Dimension>]], timestamp: Date?) {
        self.name = name
        self.location = location
        self.placemark = nil
        self.customData = nil
        self.measurements = measurements
        self.timestamp = timestamp
    }

    public init(name: String, location: Location, placemark: String?, measurements: [ProcessSelector: [ProcessValue<Dimension>]], timestamp: Date?) {
        self.name = name
        self.location = location
        self.placemark = placemark
        self.customData = nil
        self.measurements = measurements
        self.timestamp = timestamp
    }

    public init(name: String, location: Location, placemark: String?, customData: [String: Any]?, measurements: [ProcessSelector: [ProcessValue<Dimension>]], timestamp: Date?) {
        self.name = name
        self.location = location
        self.placemark = placemark
        self.customData = customData
        self.measurements = measurements
        self.timestamp = timestamp
    }
}
