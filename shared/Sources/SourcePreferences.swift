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

    /// Whether the first level gauge may be on any waterway, canals included, rather than the nearest natural one. The name is historical;
    /// the settings show it as the Any Waterway choice of `LevelWaterways`.
    static let nearestLevelSensorKey = "nearestLevelSensor"
    /// Whether particle stations may be the nearest whatever they measure. Off, and unset, reports only stations with PM10, PM2.5, NO2 and
    /// O3. The name is historical; the settings call it Any Station.
    static let nearestParticleSensorKey = "nearestParticleSensor"

    /// Which waterways the level gauges come from, one choice in the settings over two stored switches, so the keys and everyone's choice
    /// stay as they were. The raw values only order the choices; nothing stores them.
    enum LevelWaterways: Int, CaseIterable, Sendable {
        /// Gauges on the nearest natural waterway, the default.
        case natural
        /// The first gauge on the nearest natural waterway, the others the nearest on any waterway. Only differs from `natural` while
        /// Multiple Sensors is on, since without extra gauges there is nothing for it to change.
        case naturalFirst
        /// The nearest gauges on any waterway, canals included.
        case any

        var label: String {
            switch self {
                case .natural: return "Natural"
                case .naturalFirst: return "Natural First"
                case .any: return "Any Waterway"
            }
        }

        var explanation: String {
            switch self {
                case .natural:
                    return "Gauges on the nearest river or stream. Where there is none within 10 km, the nearest gauges, canals included."
                case .naturalFirst:
                    return "The first gauge on the nearest river or stream, the others the nearest gauges on any waterway, canals included."
                case .any:
                    return "The nearest gauges on any waterway, canals included, even where a river is close by."
            }
        }

        /// The choices worth offering: without extra gauges `naturalFirst` is the same as `natural`.
        static func choices(multiSensor: Bool) -> [Self] {
            return multiSensor == true ? Self.allCases : [.natural, .any]
        }

        /// The choice the stored switches amount to. Any Waterway wins, because with it nothing is tied to one waterway any more.
        init(nearest: Bool, otherWaterways: Bool, multiSensor: Bool) {
            if nearest == true {
                self = .any
            }
            else if otherWaterways == true && multiSensor == true {
                self = .naturalFirst
            }
            else {
                self = .natural
            }
        }

        /// The stored switches for this choice.
        var switches: (nearest: Bool, otherWaterways: Bool) {
            switch self {
                case .natural: return (false, false)
                case .naturalFirst: return (false, true)
                case .any: return (true, false)
            }
        }
    }

    /// How many stations the Particles tab reports where level and radiation report three. It is a tab of its own, so its stations share
    /// no colors with the Environment tab and can have all six label colors, one each, and six is exactly what the label placement solver
    /// was built for. It costs one request per station, so twice as many as before.
    static let particlesSensorMaximum = 6

    /// How many sensors each of level, radiation and particles reports on macOS with its switch on. Each has a tab and a map of its own
    /// there, so each can use all six label colors, and six is what the label placement solver was built for.
    static let macOSSensorMaximum = 6

    /// The most sensors a source reports with its switch on. On iOS every source takes the platform cap except particles, which have a tab
    /// of their own; level and radiation share the Environment map, three each. On macOS the three sources with a switch take six.
    static func sensorMaximum(forKey key: String) -> Int {
        #if os(iOS)
        if key == Self.multiSensorParticlesKey {
            return Self.particlesSensorMaximum
        }
        #else
        if [Self.multiSensorLevelKey, Self.multiSensorRadiationKey, Self.multiSensorParticlesKey].contains(key) == true {
            return Self.macOSSensorMaximum
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
