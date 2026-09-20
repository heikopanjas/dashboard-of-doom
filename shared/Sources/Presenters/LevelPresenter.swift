import DoomKitTools
import DoomKitProcess
import DoomKitLocation
import SwiftUI

@Observable class LevelPresenter: ProcessPresenter, ProcessRefreshable {
    @ObservationIgnored private var subscription: ConditionalSubscription?
    @ObservationIgnored private let fetch: @MainActor (Location) async throws -> [ProcessSensor]

    init(defaults: UserDefaults = .standard,
         register: (@MainActor (any ProcessRefreshable, TimeInterval) -> Void)? = nil,
         remove: (@MainActor (UUID) -> Void)? = nil,
         fetch: (@MainActor (Location) async throws -> [ProcessSensor])? = nil) {
        self.fetch = fetch ?? { location in return try await LevelController().refreshData(for: location) }
        super.init()
        let id = self.id
        self.subscription = ConditionalSubscription(
            defaults: defaults, enableKey: SourcePreferences.waterKey, intervalKey: "levelRefreshInterval", fallback: 15,
            register: { [weak self] interval in
                guard let self else { return }
                if let register { register(self, interval) }
                else { AppProcess.shared.add(subscriber: self, timeout: interval) }
            },
            remove: {
                if let remove { remove(id) }
                else { AppProcess.shared.remove(id: id) }
            })
    }

    func refreshData(location: Location) async -> Void {
        guard self.subscription?.isEnabled == true, Task.isCancelled == false else { return }
        do {
            if let sensor = try await self.fetch(location).first {
                try Task.checkCancellation()
                let transformer = LevelTransformer()
                try transformer.renderData(sensor: sensor)
                try Task.checkCancellation()
                guard self.subscription?.isEnabled == true else { return }
                self.publishData(sensor: sensor, transformer: transformer)
            }
        }
        catch is CancellationError { return }
        catch {
            guard Task.isCancelled == false else { return }
            trace.error("Error refreshing data: %@", error.localizedDescription)
        }
    }

    @MainActor func publishData(sensor: ProcessSensor, transformer: LevelTransformer) -> Void {
        self.sensor = sensor
        self.timestamp = sensor.timestamp
        self.measurements = transformer.measurements
        self.current = transformer.current
        self.faceplate = transformer.faceplate
        self.range = transformer.range
        self.trend = transformer.trend

        if UserDefaults.standard.bool(forKey: SourcePreferences.waterKey) == true {
            MapPresenter.shared.updateRegion(for: self.id, with: sensor.location)
        }
        else {
            MapPresenter.shared.updateRegion(remove: self.id)
        }
    }
}
