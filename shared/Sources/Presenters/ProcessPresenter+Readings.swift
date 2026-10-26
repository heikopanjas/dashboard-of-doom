import DoomKitProcess

extension ProcessPresenter {
    /// The readings a view should list: all of them when the source's multi-sensor preference is on, otherwise only the nearest.
    ///
    /// The view trims rather than only the fetch, because the presenter keeps the readings of its last refresh: switching the preference
    /// off then takes effect at once, and does not wait for a refresh, which might fail, to replace them.
    @MainActor func visibleReadings(multiSensor: Bool) -> [ProcessReading] {
        if multiSensor == true {
            return self.readings
        }
        return Array(self.readings.prefix(1))
    }
}
