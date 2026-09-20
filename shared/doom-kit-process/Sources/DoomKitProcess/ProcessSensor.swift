import DoomKitLocation
import Foundation

public class ProcessSensor: Identifiable, ProcessLocatable {
    /// The most sensors a single source reports, which is as many as the platform shows: iOS lists them, macOS shows only the nearest, so
    /// fetching more there would download data nobody sees.
    #if os(iOS)
    public static let maximumPerSource = 3
    #else
    public static let maximumPerSource = 1
    #endif

    /// Regenerated for every instance, so it changes on each refresh. Use `sourceID` to recognise the same physical sensor across refreshes.
    public let id = UUID()
    public let name: String
    public let location: Location
    public let placemark: String?
    public let customData: [String: Any]?
    public let measurements: [ProcessSelector: [ProcessValue<Dimension>]]
    public let timestamp: Date?

    /// The identifier the data provider uses for this sensor, stable across refreshes.
    public let sourceID: String?

    /// Great-circle distance from the user in metres, when the source resolved it.
    public let distance: Double?

    public init(name: String, location: Location, measurements: [ProcessSelector: [ProcessValue<Dimension>]], timestamp: Date?) {
        self.name = name
        self.location = location
        self.placemark = nil
        self.customData = nil
        self.measurements = measurements
        self.timestamp = timestamp
        self.sourceID = nil
        self.distance = nil
    }

    public init(name: String, location: Location, placemark: String?, measurements: [ProcessSelector: [ProcessValue<Dimension>]], timestamp: Date?) {
        self.name = name
        self.location = location
        self.placemark = placemark
        self.customData = nil
        self.measurements = measurements
        self.timestamp = timestamp
        self.sourceID = nil
        self.distance = nil
    }

    public init(
        name: String, location: Location, placemark: String?, customData: [String: Any]?, measurements: [ProcessSelector: [ProcessValue<Dimension>]],
        timestamp: Date?, sourceID: String? = nil, distance: Double? = nil
    ) {
        self.name = name
        self.location = location
        self.placemark = placemark
        self.customData = customData
        self.measurements = measurements
        self.timestamp = timestamp
        self.sourceID = sourceID
        self.distance = distance
    }
}
