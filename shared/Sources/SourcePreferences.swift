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

    /// How many stations the Particles tab reports where level and radiation report three. It is a tab of its own, so its stations share
    /// no colors with the Environment tab and can have all six label colors, one each, and six is exactly what the label placement solver
    /// was built for. It costs one request per station, so twice as many as before.
    static let particlesSensorMaximum = 6

    /// The most sensors a source reports with its switch on. Every source takes the platform cap except particles, which take more on iOS.
    /// macOS shows only the nearest whatever the source, so there it stays at the platform cap.
    static func sensorMaximum(forKey key: String) -> Int {
        #if os(iOS)
        if key == Self.multiSensorParticlesKey {
            return Self.particlesSensorMaximum
        }
        #endif
        return ProcessSensor.maximumPerSource
    }

    /// How many sensors a source fetches: its cap when its multi-sensor preference is on, otherwise one, which is what every source did
    /// before it could report several.
    static func sensorLimit(forKey key: String, defaults: UserDefaults = .standard) -> Int {
        if defaults.bool(forKey: key) == true {
            return Self.sensorMaximum(forKey: key)
        }
        return 1
    }

    /// Which fuel the station list ranks and shows, which way round it ranks, and how far it looks. Raw values are stored, so the
    /// orders of `FuelStation.Fuel` and the list's own order enum must not be renumbered.
    static let fuelTypeKey = "fuelType"
    static let fuelOrderKey = "fuelOrder"
    static let fuelRadiusKey = "fuelRadius"

    /// The radii the settings offer. Tankerkoenig caps the search at 25 km: a larger radius returns exactly the same stations.
    static let fuelRadiusChoices = [5, 10, 25]
    static let fuelRadiusDefault = 10

    /// The stored search radius in kilometres, clamped to something the API will answer. Unset reads as the default.
    static func fuelRadius(defaults: UserDefaults = .standard) -> Double {
        let stored = defaults.integer(forKey: Self.fuelRadiusKey)
        let kilometres = stored > 0 ? stored : Self.fuelRadiusDefault
        return Double(min(max(kilometres, 1), 25))
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
