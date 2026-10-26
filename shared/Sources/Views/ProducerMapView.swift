import DoomKitProcess
import SwiftUI

/// The Gulf six on a map, each labelled with its latest reported production in its own colour, the colour its chart header has. The
/// reader's position is left off: it has nothing to do with where oil is produced, and would stretch the camera to Germany.
struct ProducerMapView: View {
    @Environment(ProducerPresenter.self) private var presenter

    var body: some View {
        SensorMapView(annotations: Self.annotations(self.presenter.readings), showsUser: false)
    }

    /// One label per country, in the presenter's order, which is `ProducerController.producers`'. The id is the country code, so a
    /// label keeps its placement across refreshes.
    static func annotations(_ readings: [ProcessReading]) -> [MapAnnotationSnapshot] {
        let selector = ProcessSelector.energy(.production)
        return readings.enumerated().map { index, reading in
            return MapAnnotationSnapshot(
                id: "producer-\(reading.sensor.sourceID ?? reading.sensor.name)", location: reading.sensor.location, selector: selector,
                icon: reading.sensor.customData?["icon"] as? String ?? "drop.fill", faceplate: reading.faceplate[selector] ?? "n/a",
                color: Color.sensor(selector: selector, index: index))
        }
    }
}
