import DoomKitProcess
import SwiftUI

/// The map labels of a source's sensors, one per reading, nearest first. Both platforms build their sensor maps from these: iOS puts
/// radiation and level on one Environment map, macOS gives each source a tab and a map of its own.
enum SensorAnnotations {
    static func water(_ readings: [ProcessReading]) -> [MapAnnotationSnapshot] {
        return Self.snapshots(of: readings, category: "water", selector: { _ in .water(.level) })
    }

    static func radiation(_ readings: [ProcessReading]) -> [MapAnnotationSnapshot] {
        return Self.snapshots(of: readings, category: "radiation", selector: { _ in .radiation(.total) })
    }

    static func particles(_ readings: [ProcessReading]) -> [MapAnnotationSnapshot] {
        return Self.snapshots(of: readings, category: "particles", selector: Self.particleSelector(for:))
    }

    /// A station reports up to a dozen pollutants but a label has room for one. It shows the first the tab lists, which is the first chart
    /// under it, and PM10 when there is no value at all, so an empty station still gets a label.
    static func particleSelector(for reading: ProcessReading) -> ProcessSelector {
        // The first case is a marker for all pollutants, which no station reports.
        for pollutant in ProcessSelector.Particle.allCases where pollutant != .all && reading.faceplate[.particle(pollutant)] != nil {
            return .particle(pollutant)
        }
        return .particle(.pm10)
    }

    /// Ids come from the reading, which is the source's own id, so a sensor keeps its label placement across refreshes; the category keeps a
    /// level gauge and a radiation station apart, and an id used twice would silently drop a label. The position in the list picks the
    /// color, the same one the header of that sensor's section uses.
    private static func snapshots(
        of readings: [ProcessReading], category: String, selector: (ProcessReading) -> ProcessSelector
    ) -> [MapAnnotationSnapshot] {
        return readings.enumerated().map { index, reading in
            let selector = selector(reading)
            return MapAnnotationSnapshot(
                id: "\(category)-\(reading.id)", location: reading.sensor.location, selector: selector,
                icon: (reading.sensor.customData?["icon"] as? String) ?? "questionmark.circle", faceplate: reading.faceplate[selector] ?? "n/a",
                color: Color.sensor(selector: selector, index: index))
        }
    }
}
