import DoomKitLocation
import DoomKitProcess
import DoomKitTools
import Foundation
import SwiftUI

@Observable class SurveyPresenter: ProcessPresenter, ProcessRefreshable {
    @ObservationIgnored private var subscription: ConditionalSubscription?
    @ObservationIgnored private let fetch: @MainActor (Location) async throws -> [ProcessSensor]

    init(
        defaults: UserDefaults = .standard,
        register: (@MainActor (any ProcessRefreshable, TimeInterval) -> Void)? = nil,
        remove: (@MainActor (UUID) -> Void)? = nil,
        fetch: (@MainActor (Location) async throws -> [ProcessSensor])? = nil
    ) {
        self.fetch = fetch ?? { location in return try await SurveyController().refreshData(for: location) }
        super.init()
        let id = self.id
        self.subscription = ConditionalSubscription(
            defaults: defaults, enableKey: SourcePreferences.pollsEnableKey, intervalKey: "surveyRefreshInterval", fallback: 360,
            defaultEnabled: SourcePreferences.pollsEnabledByDefault,
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

    func gradient(selector: ProcessSelector) -> LinearGradient {
        switch selector {
            case .survey(.fascists):
                return Gradient.fascists
            case .survey(.afd):
                return Gradient.fascists
            case .survey(.bsw):
                return Gradient.clowns
            case .survey(.clowns):
                return Gradient.clowns
            case .survey(.fdp):
                return Gradient.clowns
            case .survey(.freie_waehler):
                return Gradient.clowns
            case .survey(.cducsu):
                return Gradient.fascists
            case .survey(.cdu):
                return Gradient.fascists
            case .survey(.csu):
                return Gradient.fascists
            case .survey(.spd):
                return Gradient.spd
            case .survey(.gruene):
                return Gradient.gruene
            case .survey(.linke):
                return Gradient.linke
            case .survey(.sonstige):
                return Gradient.sonstige
            default:
                return Gradient.linear
        }
    }

    func refreshData(location: Location) async -> Void {
        guard self.subscription?.isEnabled == true, Task.isCancelled == false else { return }
        trace.debug("SurveyPresenter.refreshData() called, ID: \(self.id)")
        do {
            let sensors = try await self.fetch(location)
            try Task.checkCancellation()
            let readings = try ProcessReading.render(sensors: sensors, transformer: { SurveyTransformer() })
            try Task.checkCancellation()
            guard self.subscription?.isEnabled == true else { return }
            self.publish(readings: readings, map: .conditional { SourcePreferences.pollsVisible() == true })
        }
        catch is CancellationError { return }
        catch {
            guard Task.isCancelled == false else { return }
            trace.error("Error refreshing data: %@", error.localizedDescription)
        }
    }
}
