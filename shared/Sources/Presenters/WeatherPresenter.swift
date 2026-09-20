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
            let sensors = try await self.fetch(location)
            try Task.checkCancellation()
            let readings = try ProcessReading.render(sensors: sensors, transformer: { WeatherTransformer() })
            try Task.checkCancellation()
            self.publish(readings: readings, map: .always)
        }
        catch is CancellationError { return }
        catch {
            guard Task.isCancelled == false else { return }
            trace.error("Error refreshing data: %@", error.localizedDescription)
        }
    }
}
