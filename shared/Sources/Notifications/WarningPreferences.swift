import Foundation

/// The two limits of a rule, already ordered: for a rule warning above its limits the critical one is never below the warning one, and the
/// other way round for one warning below. A critical value entered on the wrong side therefore acts as the warning value.
struct WarningLimits: Equatable {
    let warning: Double
    let critical: Double
}

/// The keys and defaults of everything notifications read. Every value is read so that unset means the default and a launch argument such
/// as `-warning.radiation.total.warning 0.01` reaches it: `bool(forKey:)` and `double(forKey:)` parse the strings launch arguments arrive as.
enum WarningPreferences {
    /// The master switch. Off, and unset, sends nothing; turning it on asks for permission.
    static let enabledKey = "notificationsEnabled"
    /// What was notified and when, so a background launch knows it too.
    static let stateKey = "warningState"
    /// The lowest hazard severity that warns, and the lowest that is critical, as `Hazard.Severity` raw values.
    static let hazardWarningKey = "warning.hazards.warning"
    static let hazardCriticalKey = "warning.hazards.critical"

    static func familyKey(_ family: WarningFamily) -> String {
        return "notify.\(family.rawValue)"
    }

    static func warningKey(_ rule: WarningRule) -> String {
        return "warning.\(rule.id).warning"
    }

    static func criticalKey(_ rule: WarningRule) -> String {
        return "warning.\(rule.id).critical"
    }

    static func isEnabled(defaults: UserDefaults = .standard) -> Bool {
        return defaults.bool(forKey: Self.enabledKey)
    }

    static func isEnabled(_ family: WarningFamily, defaults: UserDefaults = .standard) -> Bool {
        guard defaults.object(forKey: Self.familyKey(family)) != nil else { return family.enabledByDefault }
        return defaults.bool(forKey: Self.familyKey(family))
    }

    static func limits(for rule: WarningRule, defaults: UserDefaults = .standard) -> WarningLimits {
        let warning = Self.clamp(Self.double(Self.warningKey(rule), default: rule.defaultWarning, defaults: defaults), to: rule.range)
        let critical = Self.clamp(Self.double(Self.criticalKey(rule), default: rule.defaultCritical, defaults: defaults), to: rule.range)
        switch rule.direction {
            case .above:
                return WarningLimits(warning: warning, critical: max(critical, warning))
            case .below:
                return WarningLimits(warning: warning, critical: min(critical, warning))
        }
    }

    static let hazardWarningDefault = Hazard.Severity.moderate
    static let hazardCriticalDefault = Hazard.Severity.severe

    /// The hazard severities, ordered like the rule limits. `unknown` is not a limit: a warning without a severity should not be the bar.
    static func hazardLimits(defaults: UserDefaults = .standard) -> (warning: Hazard.Severity, critical: Hazard.Severity) {
        let warning = Self.severity(Self.hazardWarningKey, default: Self.hazardWarningDefault, defaults: defaults)
        let critical = Self.severity(Self.hazardCriticalKey, default: Self.hazardCriticalDefault, defaults: defaults)
        return (warning, max(critical, warning))
    }

    private static func double(_ key: String, default value: Double, defaults: UserDefaults) -> Double {
        guard defaults.object(forKey: key) != nil else { return value }
        let stored = defaults.double(forKey: key)
        return stored.isFinite == true ? stored : value
    }

    private static func severity(_ key: String, default value: Hazard.Severity, defaults: UserDefaults) -> Hazard.Severity {
        guard defaults.object(forKey: key) != nil, let severity = Hazard.Severity(rawValue: defaults.integer(forKey: key)),
            severity != .unknown
        else { return value }
        return severity
    }

    private static func clamp(_ value: Double, to range: ClosedRange<Double>) -> Double {
        return min(max(value, range.lowerBound), range.upperBound)
    }
}
