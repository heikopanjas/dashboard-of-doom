import DoomKitProcess
import SwiftUI

/// The map of the particulate stations at the top of the Particles tab: a dot and a label for every station the tab lists.
struct ParticleMapView: View {
    @Environment(ParticlePresenter.self) private var particles
    @AppStorage(SourcePreferences.multiSensorParticlesKey) private var multiSensor: Bool = false

    var body: some View {
        // The same readings the sections below list, so switching Multiple Sensors off removes the extra labels at once.
        SensorMapView(annotations: Self.annotations(particles: self.particles.visibleReadings(multiSensor: self.multiSensor)))
    }

    /// One annotation per station. The id is the station's own, so a station keeps its label placement across refreshes, and the position in
    /// the list picks the color, the same one the section for that station below the map uses for its header.
    static func annotations(particles readings: [ProcessReading]) -> [MapAnnotationSnapshot] {
        return readings.enumerated().map { index, reading in
            let selector = Self.selector(for: reading)
            return MapAnnotationSnapshot(
                id: "particles-\(reading.id)", location: reading.sensor.location, selector: selector,
                icon: (reading.sensor.customData?["icon"] as? String) ?? "questionmark.circle", faceplate: reading.faceplate[selector] ?? "n/a",
                color: Color.sensor(selector: selector, index: index))
        }
    }

    /// A station reports up to a dozen pollutants but a label has room for one. It shows the first the tab lists, which is the first chart
    /// under it, and PM10 when there is no value at all, so an empty station still gets a label.
    static func selector(for reading: ProcessReading) -> ProcessSelector {
        // The first case is a marker for all pollutants, which no station reports.
        for pollutant in ProcessSelector.Particle.allCases where pollutant != .all && reading.faceplate[.particle(pollutant)] != nil {
            return .particle(pollutant)
        }
        return .particle(.pm10)
    }
}
