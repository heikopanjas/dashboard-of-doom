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

    /// One annotation per station, built by `SensorAnnotations`, which macOS uses as well.
    static func annotations(particles readings: [ProcessReading]) -> [MapAnnotationSnapshot] {
        return SensorAnnotations.particles(readings)
    }

    static func selector(for reading: ProcessReading) -> ProcessSelector {
        return SensorAnnotations.particleSelector(for: reading)
    }
}
