import DoomKitLocation
import DoomKitProcess
import DoomKitServices
import Foundation

/// A station with its fetched series, before it becomes a `ProcessSensor`.
struct SensorCandidate {
    let id: String
    let name: String
    let location: Location
    let customData: [String: Any]
    /// One series per selector; a source with a single measurement has a single entry.
    let measurements: [ProcessSelector: [ProcessValue<Dimension>]]

    /// Whether any series has a value, so a station that answered with nothing can be told from one that did not.
    var hasData: Bool {
        return self.measurements.values.contains { $0.isEmpty == false }
    }

    /// Builds the sensors of a source from its candidates, which must already be ordered nearest first.
    ///
    /// The first sensor is the one the app shows, so it needs a placemark: candidates are geocoded in order until one succeeds, and the
    /// candidates before it are dropped. Only that sensor is geocoded, since nothing displays the others. Every later candidate is kept
    /// only when it has data; the first one is kept even without, so a station outage shows an empty chart rather than moving the pin.
    static func sensors(
        from candidates: [SensorCandidate], near location: Location,
        geocode: (Location) async -> String? = { await GeocodingService.reverseGeocodeLocation(location: $0) }
    ) async throws -> [ProcessSensor] {
        var sensors: [ProcessSensor] = []
        for candidate in candidates {
            if sensors.isEmpty == true {
                try Task.checkCancellation()
                if let placemark = await geocode(candidate.location) {
                    try Task.checkCancellation()
                    sensors.append(candidate.sensor(placemark: placemark, near: location))
                }
            }
            else if candidate.hasData == true {
                sensors.append(candidate.sensor(placemark: nil, near: location))
            }
        }
        return sensors
    }

    private func sensor(placemark: String?, near location: Location) -> ProcessSensor {
        let measurements = self.measurements.filter { $0.value.isEmpty == false }
        let distance = haversineDistance(location_0: location, location_1: self.location).converted(to: .meters).value
        return ProcessSensor(
            name: self.name, location: self.location, placemark: placemark, customData: self.customData, measurements: measurements,
            timestamp: Date.now, sourceID: self.id, distance: distance)
    }
}
