import SwiftUI

struct RadiationMapView: View {
    @Environment(RadiationPresenter.self) private var presenter
    @AppStorage(SourcePreferences.multiSensorRadiationKey) private var multiSensor: Bool = false

    var body: some View {
        SensorMapView(annotations: SensorAnnotations.radiation(self.presenter.visibleReadings(multiSensor: self.multiSensor)))
    }
}
