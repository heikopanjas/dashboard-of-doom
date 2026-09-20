import DoomKitTools
import DoomKitProcess
import DoomKitLocation
import SwiftUI

@Observable class EnergyPresenter: ProcessPresenter, ProcessRefreshable {
    @ObservationIgnored private var subscription: ConditionalSubscription?
    @ObservationIgnored private let fetch: @MainActor (Location) async throws -> [ProcessSensor]

    init(defaults: UserDefaults = .standard,
         register: (@MainActor (any ProcessRefreshable, TimeInterval) -> Void)? = nil,
         remove: (@MainActor (UUID) -> Void)? = nil,
         fetch: (@MainActor (Location) async throws -> [ProcessSensor])? = nil) {
        self.fetch = fetch ?? { location in return try await EnergyController().refreshData(for: location) }
        super.init()
        let id = self.id
        // The prices change once a day, so six hours is plenty.
        self.subscription = ConditionalSubscription(
            defaults: defaults, enableKey: SourcePreferences.energyEnableKey, intervalKey: "energyRefreshInterval", fallback: 360,
            defaultEnabled: SourcePreferences.energyEnabledByDefault,
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
            let sensors = try await self.fetch(location)
            try Task.checkCancellation()
            let readings = try ProcessReading.render(sensors: sensors, transformer: { EnergyTransformer() })
            try Task.checkCancellation()
            guard self.subscription?.isEnabled == true else { return }
            // Prices have no place, so they are never on the map.
            self.publish(readings: readings, map: .never)
        }
        catch is CancellationError { return }
        catch {
            guard Task.isCancelled == false else { return }
            trace.error("Error refreshing data: %@", error.localizedDescription)
        }
    }
}
