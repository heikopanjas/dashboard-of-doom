import DoomKitLocation
import DoomKitProcess
import SwiftUI

/// The map of the reporting district at the top of the COVID tab: its outline shaded, one label at its centroid, and the reader's own dot.
///
/// COVID has no sensor. The numbers are district-wide and the location under them is the polygon's centroid, a computed point, so the
/// outline is the only thing that says what area they cover, and the reader's dot the only thing that says whether they are inside it.
struct CovidMapView: View {
    @Environment(CovidPresenter.self) private var presenter

    var body: some View {
        // A district fills its own frame, so it needs room for one label rather than the six the other maps leave room for.
        SensorMapView(
            annotations: Self.annotations(covid: self.presenter.readings), polygons: Self.polygons(covid: self.presenter.readings),
            padding: 1.15)
    }

    /// The single label, at the district's centroid, showing the incidence. The id is fixed rather than the reading's, because COVID always
    /// reports exactly one district and `ProcessReading.id` changes on every refresh, which would move the label's placement with it.
    static func annotations(covid readings: [ProcessReading]) -> [MapAnnotationSnapshot] {
        guard let reading = readings.first else {
            return []
        }
        let selector = ProcessSelector.covid(.incidence)
        return [
            MapAnnotationSnapshot(
                id: "covid", location: reading.sensor.location, selector: selector,
                icon: (reading.sensor.customData?["icon"] as? String) ?? "facemask", faceplate: reading.faceplate[selector] ?? "n/a")
        ]
    }

    /// The district's outline, which `CovidController` puts in `customData` after using it to resolve which district the reader is in. A
    /// sensor without one simply draws no shape, which is what macOS and any other source would give.
    static func polygons(covid readings: [ProcessReading]) -> [[Location]] {
        return (readings.first?.sensor.customData?["polygons"] as? [[Location]]) ?? []
    }
}
