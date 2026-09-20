import DoomKitProcess

extension ProcessPresenter {
    /// Publishes the readings and updates the map region from the nearest sensor. The map is keyed by presenter, so only the nearest sensor
    /// takes part. An empty array changes nothing, neither the readings nor the map, so a failed refresh cannot move the camera.
    @MainActor func publish(readings: [ProcessReading], map: ProcessMapVisibility) -> Void {
        guard let location = readings.first?.sensor.location else { return }
        self.publish(readings: readings)

        let isVisible: Bool
        switch map {
            case .never:
                return
            case .always:
                isVisible = true
            case .conditional(let condition):
                isVisible = condition()
        }
        if isVisible == true {
            MapPresenter.shared.updateRegion(for: self.id, with: location)
        }
        else {
            MapPresenter.shared.updateRegion(remove: self.id)
        }
    }
}
