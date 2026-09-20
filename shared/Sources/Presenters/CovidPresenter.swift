import DoomKitTools
import DoomKitProcess
import DoomKitLocation
import Foundation

@Observable class CovidPresenter: ProcessPresenter, ProcessRefreshable {
    @ObservationIgnored private var subscription: ConditionalSubscription?
    @ObservationIgnored private let fetch: @MainActor (Location) async throws -> [ProcessSensor]

    init(defaults: UserDefaults = .standard,
         register: (@MainActor (any ProcessRefreshable, TimeInterval) -> Void)? = nil,
         remove: (@MainActor (UUID) -> Void)? = nil,
         fetch: (@MainActor (Location) async throws -> [ProcessSensor])? = nil) {
        self.fetch = fetch ?? { location in return try await CovidController().refreshData(for: location) }
        super.init()
        let id = self.id
        self.subscription = ConditionalSubscription(
            defaults: defaults, enableKey: "showCovid", intervalKey: "covidRefreshInterval", fallback: 360,
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
            let readings = try ProcessReading.render(sensors: sensors, transformer: { CovidTransformer() })
            try Task.checkCancellation()
            guard self.subscription?.isEnabled == true else { return }
            self.publish(readings: readings, map: .conditional { UserDefaults.standard.bool(forKey: "showCovid") == true })
        }
        catch is CancellationError { return }
        catch {
            guard Task.isCancelled == false else { return }
            trace.error("Error refreshing data: %@", error.localizedDescription)
        }
    }
}
