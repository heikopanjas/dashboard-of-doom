import DoomKitTools
import DoomKitProcess
import DoomKitLocation
import SwiftUI

@Observable class ForecastPresenter: ProcessPresenter, ProcessRefreshable {
    @ObservationIgnored private let fetch: @MainActor (Location) async throws -> [ProcessSensor]

    init(defaults: UserDefaults = .standard,
         register: (@MainActor (any ProcessRefreshable, TimeInterval) -> Void)? = nil,
         fetch: (@MainActor (Location) async throws -> [ProcessSensor])? = nil) {
        self.fetch = fetch ?? { location in return try await ForecastController().refreshData(for: location) }
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
                let transformer = ForecastTransformer()
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

    @MainActor func publishData(sensor: ProcessSensor, transformer: ForecastTransformer) -> Void {
        self.sensor = sensor
        self.timestamp = sensor.timestamp

        self.measurements = transformer.measurements
        self.current = transformer.current
        self.faceplate = transformer.faceplate
        self.range = transformer.range
        self.trend = transformer.trend
    }
}
