import Foundation

/// Historical app preference keys are preserved independently on each platform.
enum SourcePreferences {
    #if os(iOS)
    static let waterKey = "showWater"
    static let pollsEnableKey = "enableElectionPolls"
    static let pollsEnabledByDefault = false
    #else
    static let waterKey = "showLevels"
    static let pollsEnableKey = "showElectionPolls"
    static let pollsEnabledByDefault = true
    #endif

    static func pollsVisible(defaults: UserDefaults = .standard) -> Bool {
        let enabled = defaults.object(forKey: Self.pollsEnableKey) as? Bool ?? Self.pollsEnabledByDefault
        return enabled && (defaults.object(forKey: "showElectionPolls") as? Bool ?? true)
    }
}
