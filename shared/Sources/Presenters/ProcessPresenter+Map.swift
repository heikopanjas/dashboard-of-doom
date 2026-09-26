import DoomKitProcess

extension ProcessPresenter {
    /// Publishes the readings, checks them against the warning limits and updates the map region from the nearest sensor. The map is keyed
    /// by presenter, so only the nearest sensor takes part; the warnings look at every sensor. An empty array changes nothing, neither the
    /// readings nor the map, so a failed refresh cannot move the camera. Fixtures use `replace(readings:)` and so never notify.
    @MainActor func publish(readings: [ProcessReading], map: ProcessMapVisibility) -> Void {
        guard let location = readings.first?.sensor.location else { return }
        self.publish(readings: readings)
        WarningNotifier.shared.check(readings: readings)

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
