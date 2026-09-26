import DoomKitLocation
import DoomKitProcess
import DoomKitTools
import Foundation

/// What gets posted: the assessment that raised the level. The identifier is the assessment's key, so a newer notice about the same sensor
/// replaces the older one instead of piling up.
struct WarningNotice: Equatable {
    let identifier: String
    let family: WarningFamily
    let level: WarningLevel
    let title: String
    let body: String
}

/// Turns assessments into notices. It notifies only when a key gets worse: normal to warning, warning to critical, or straight to critical.
/// A key back to normal is re-armed, a key that eases to warning can escalate again, and one key and level never notify twice within
/// `repeatInterval`, so a value hovering at a limit does not flap. The state lives in `UserDefaults`, because a background launch has to
/// know what the last run sent.
@MainActor
final class WarningNotifier {
    typealias Post = @MainActor (WarningNotice) -> Void

    static let shared = WarningNotifier()

    /// The shortest time between two notices of the same key and level.
    static let repeatInterval: TimeInterval = 6 * 60 * 60
    /// A key not assessed for this long is forgotten: hazard ids come and go, and a sensor can drop out of the list.
    static let retention: TimeInterval = 7 * 24 * 60 * 60

    /// One key's history. Levels are stored per input, and the worst of them is what counts.
    struct Entry: Codable, Equatable {
        var inputs: [String: WarningLevel] = [:]
        /// The level last notified and not yet re-armed.
        var notified: WarningLevel = .normal
        /// When each level was last posted, for the repeat interval.
        var posted: [WarningLevel: Date] = [:]
        var seen: Date
    }

    private let defaults: UserDefaults
    private let now: () -> Date
    private let isLocationMeasured: @MainActor () -> Bool
    private let post: Post

    init(
        defaults: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init,
        isLocationMeasured: @escaping @MainActor () -> Bool = { AppLocation.shared.state.origin == .measured },
        post: Post? = nil
    ) {
        self.defaults = defaults
        self.now = now
        self.isLocationMeasured = isLocationMeasured
        self.post = post ?? { notice in NotificationCenterPoster.shared.post(notice) }
    }

    // MARK: - Entry points

    func check(readings: [ProcessReading]) {
        guard self.isActive() else { return }
        self.process(WarningEvaluator.assessments(readings: readings, defaults: self.defaults, now: self.now()))
    }

    func check(hazards: [Hazard]) {
        guard self.isActive() else { return }
        self.process(WarningEvaluator.assessments(hazards: hazards, defaults: self.defaults))
    }

    func check(stations: [FuelStation]) {
        guard self.isActive() else { return }
        let fuel = FuelStation.Fuel(rawValue: self.defaults.integer(forKey: SourcePreferences.fuelTypeKey)) ?? .e5
        self.process(
            WarningEvaluator.assessments(
                stations: stations, fuel: fuel, radius: SourcePreferences.fuelRadius(defaults: self.defaults), defaults: self.defaults))
    }

    /// Nothing is judged while the location is the Berlin fallback, so a cold background launch cannot warn about Berlin.
    private func isActive() -> Bool {
        guard WarningPreferences.isEnabled(defaults: self.defaults) == true else { return false }
        guard self.isLocationMeasured() == true else {
            trace.debug("Warnings not checked: the location is still the fallback")
            return false
        }
        return true
    }

    // MARK: - State

    func process(_ assessments: [WarningAssessment]) {
        let now = self.now()
        var state = self.load()
        for assessment in assessments where WarningPreferences.isEnabled(assessment.family, defaults: self.defaults) == true {
            var entry = state[assessment.key] ?? Entry(seen: now)
            entry.seen = now
            entry.inputs[assessment.input] = assessment.level
            let effective = entry.inputs.values.max() ?? .normal
            if effective > entry.notified, assessment.level == effective {
                if let last = entry.posted[effective], now.timeIntervalSince(last) < Self.repeatInterval {
                    trace.debug("Warning %@ at %@ held back, sent less than six hours ago", assessment.key, effective.label)
                }
                else {
                    self.post(
                        WarningNotice(
                            identifier: assessment.key, family: assessment.family, level: effective, title: assessment.title,
                            body: assessment.body))
                    entry.posted[effective] = now
                }
                entry.notified = effective
            }
            else if effective < entry.notified {
                // Easing re-arms the levels above: back to normal re-arms everything, critical to warning re-arms critical.
                entry.notified = effective
            }
            state[assessment.key] = entry
        }
        state = state.filter { now.timeIntervalSince($0.value.seen) < Self.retention }
        self.save(state)
    }

    func load() -> [String: Entry] {
        guard let data = self.defaults.data(forKey: WarningPreferences.stateKey),
            let state = try? JSONDecoder().decode([String: Entry].self, from: data)
        else { return [:] }
        return state
    }

    private func save(_ state: [String: Entry]) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        self.defaults.set(data, forKey: WarningPreferences.stateKey)
    }
}
