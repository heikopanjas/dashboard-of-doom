import DoomKitProcess
import Foundation

/// Historical app preference keys are preserved independently on each platform.
enum SourcePreferences {
    /// Whether a source reports several sensors. Off, and unset, is the single nearest sensor. They are only read with `bool(forKey:)`, so
    /// unset means off and a launch argument such as `-multiSensorLevel YES` reaches them.
    static let multiSensorLevelKey = "multiSensorLevel"
    static let multiSensorRadiationKey = "multiSensorRadiation"
    static let multiSensorParticlesKey = "multiSensorParticles"
    /// Whether the extra level gauges may be on other waterways than the first. Off, and unset, keeps them on the same waterway.
    static let multiSensorLevelOtherWaterwaysKey = "multiSensorLevelOtherWaterways"

    /// How many sensors a source fetches: the platform cap when its multi-sensor preference is on, otherwise one, which is what every
    /// source did before it could report several.
    static func sensorLimit(forKey key: String, defaults: UserDefaults = .standard) -> Int {
        if defaults.bool(forKey: key) == true {
            return ProcessSensor.maximumPerSource
        }
        return 1
    }

    /// Whether energy prices are fetched and their tab shown. On by default; there is nothing of theirs on the map.
    static let energyEnableKey = "enableEnergy"
    static let energyEnabledByDefault = true

    #if os(iOS)
    static let waterKey = "showWater"
    static let pollsEnableKey = "enableElectionPolls"
    static let pollsEnabledByDefault = false
    /// COVID is off by default on iOS: fetching and the tab follow this key, the map label follows `showCovid` as well. macOS keeps its one
    /// switch, on by default, the way polls differ between the platforms.
    static let covidEnableKey = "enableCovid"
    static let covidEnabledByDefault = false
    #else
    static let waterKey = "showLevels"
    static let pollsEnableKey = "showElectionPolls"
    static let pollsEnabledByDefault = true
    static let covidEnableKey = "showCovid"
    static let covidEnabledByDefault = true
    #endif

    static func pollsVisible(defaults: UserDefaults = .standard) -> Bool {
        let enabled = defaults.object(forKey: Self.pollsEnableKey) as? Bool ?? Self.pollsEnabledByDefault
        return enabled && (defaults.object(forKey: "showElectionPolls") as? Bool ?? true)
    }

    static func covidVisible(defaults: UserDefaults = .standard) -> Bool {
        let enabled = defaults.object(forKey: Self.covidEnableKey) as? Bool ?? Self.covidEnabledByDefault
        return enabled && (defaults.object(forKey: "showCovid") as? Bool ?? true)
    }
}
