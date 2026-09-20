import DoomKitTools
import DoomKitProcess
import DoomKitLocation
import CoreLocation
import MapKit
import SwiftUI

@Observable class WeatherPresenter: ProcessPresenter, ProcessRefreshable {
    @ObservationIgnored private let fetch: @MainActor (Location) async throws -> [ProcessSensor]

    init(defaults: UserDefaults = .standard,
         register: (@MainActor (any ProcessRefreshable, TimeInterval) -> Void)? = nil,
         fetch: (@MainActor (Location) async throws -> [ProcessSensor])? = nil) {
        self.fetch = fetch ?? { location in return try await WeatherController().refreshData(for: location) }
        super.init(coordinator: register == nil ? AppProcess.shared : nil)
        let interval = defaults.integer(forKey: "weatherRefreshInterval")
        let timeout = TimeInterval(interval > 0 ? interval : 5)
        if let register { register(self, timeout) }
        else { AppProcess.shared.add(subscriber: self, timeout: timeout) }
    }

    func refreshData(location: Location) async -> Void {
        do {
            if let sensor = try await self.fetch(location).first {
                try Task.checkCancellation()
                let transformer = WeatherTransformer()
                try transformer.renderData(sensor: sensor)
                try Task.checkCancellation()
                self.publishData(sensor: sensor, transformer: transformer)
            }
        }
        catch is CancellationError { return }
        catch {
            guard Task.isCancelled == false else { return }
            trace.error("Error refreshing data: %@", error.localizedDescription)
        }
    }

    @MainActor func publishData(sensor: ProcessSensor, transformer: WeatherTransformer) -> Void {
        self.sensor = sensor
        self.timestamp = sensor.timestamp

        self.measurements = transformer.measurements
        self.current = transformer.current
        self.faceplate = transformer.faceplate
        self.range = transformer.range
        self.trend = transformer.trend

        MapPresenter.shared.updateRegion(for: self.id, with: sensor.location)
//        if UserDefaults.standard.bool(forKey: "showWeather") == true {
//            MapPresenter.shared.updateRegion(for: self.id, with: sensor.location)
//        }
//        else {
//            MapPresenter.shared.updateRegion(remove: self.id)
//        }
    }
}
