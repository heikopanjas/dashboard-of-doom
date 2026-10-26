import DoomKitLocation
import DoomKitProcess
import DoomKitTools
import SwiftUI

/// The market prices, Brent spot and futures, TTF and LNG, on the Energy Markets screen. The Energy Markets switch governs them.
@Observable class EnergyPresenter: ProcessPresenter, ProcessRefreshable {
    @ObservationIgnored private var subscription: ConditionalSubscription?
    @ObservationIgnored private let fetch: @MainActor (Location) async throws -> [ProcessSensor]

    init(
        defaults: UserDefaults = .standard,
        register: (@MainActor (any ProcessRefreshable, TimeInterval) -> Void)? = nil,
        remove: (@MainActor (UUID) -> Void)? = nil,
        fetch: (@MainActor (Location) async throws -> [ProcessSensor])? = nil
    ) {
        self.fetch = fetch ?? { location in return try await EnergyController().refreshData(for: location) }
        super.init()
        let id = self.id
        // EuroOilWatch refreshes daily and ACER publishes weekday assessments; keep the six-hour fallback.
        self.subscription = ConditionalSubscription(
            defaults: defaults, enableKey: SourcePreferences.marketsEnableKey, intervalKey: "energyRefreshInterval", fallback: 360,
            defaultEnabled: SourcePreferences.marketsEnabledByDefault,
            register: { [weak self] interval in
                guard let self else { return }
                if let register {
                    register(self, interval)
                }
                else {
                    AppProcess.shared.add(subscriber: self, timeout: interval)
                }
            },
            remove: {
                if let remove {
                    remove(id)
                }
                else {
                    AppProcess.shared.remove(id: id)
                }
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
