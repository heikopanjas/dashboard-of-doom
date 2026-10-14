import SwiftUI

struct LevelMapView: View {
    @Environment(LevelPresenter.self) private var presenter
    @AppStorage(SourcePreferences.multiSensorLevelKey) private var multiSensor: Bool = false

    var body: some View {
        SensorMapView(annotations: SensorAnnotations.water(self.presenter.visibleReadings(multiSensor: self.multiSensor)))
    }
}
