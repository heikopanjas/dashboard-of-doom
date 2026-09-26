import DoomKitProcess
import Foundation

/// A value the macOS status item can show. Up to two are shown, from any sources, after the vertical "DOD" tag.
///
/// The model follows senor-particle's `StatusBarDisplayMetric` (github.com/heikopanjas/senor-particle), with sources in place of devices.
enum StatusBarValue: String, CaseIterable, Sendable {
    case temperature
    case apparentTemperature
    case humidity
    case windSpeed
    case windGust
    case pressure
    case covidIncidence
    case waterLevel
    case radiation
    case pm10
    case pm25
    case no2
    case o3
    case brent
    case wti
    case lng

    /// The source a value belongs to, which groups the choices in Settings and decides whether the value can be shown.
    enum Source: String, CaseIterable, Sendable {
        case weather, covid, water, radiation, particles, energy

        var label: String {
            switch self {
                case .weather: return "Weather"
                case .covid: return "COVID-19"
                case .water: return "Water Level"
                case .radiation: return "Radiation"
                case .particles: return "Particulate Matter"
                case .energy: return "Energy"
            }
        }

        /// The SF Symbol in front of the source's values in the Settings list.
        var symbol: String {
            switch self {
                case .weather: return "thermometer.medium"
                case .covid: return "facemask"
                case .water: return "water.waves"
                case .radiation: return "atom"
                case .particles: return "aqi.medium"
                case .energy: return "fuelpump"
            }
        }

        /// Weather always updates; every other source only while its switch is on.
        func isAvailable(defaults: UserDefaults = .standard) -> Bool {
            switch self {
                case .weather: return true
                case .covid: return SourcePreferences.covidVisible(defaults: defaults)
                case .water: return SourcePreferences.waterVisible(defaults: defaults)
                case .radiation: return SourcePreferences.radiationVisible(defaults: defaults)
                case .particles: return SourcePreferences.particlesVisible(defaults: defaults)
                case .energy: return SourcePreferences.energyVisible(defaults: defaults)
            }
        }
    }

    var source: Source {
        switch self {
            case .temperature, .apparentTemperature, .humidity, .windSpeed, .windGust, .pressure: return .weather
            case .covidIncidence: return .covid
            case .waterLevel: return .water
            case .radiation: return .radiation
            case .pm10, .pm25, .no2, .o3: return .particles
            case .brent, .wti, .lng: return .energy
        }
    }

    var label: String {
        switch self {
            case .temperature: return "Temperature"
            case .apparentTemperature: return "Feels Like"
            case .humidity: return "Humidity"
            case .windSpeed: return "Wind"
            case .windGust: return "Gusts"
            case .pressure: return "Pressure"
            case .covidIncidence: return "Incidence"
            case .waterLevel: return "Level"
            case .radiation: return "Dose Rate"
            case .pm10: return "PM10"
            case .pm25: return "PM2.5"
            case .no2: return "NO2"
            case .o3: return "Ozone"
            case .brent: return "Brent"
            case .wti: return "WTI"
            case .lng: return "EU LNG"
        }
    }

    /// The series whose faceplate, the string the map labels show, is the value.
    var selector: ProcessSelector {
        switch self {
            case .temperature: return .weather(.temperature)
            case .apparentTemperature: return .weather(.apparentTemperature)
            case .humidity: return .weather(.humidity)
            case .windSpeed: return .weather(.windSpeed)
            case .windGust: return .weather(.windGust)
            case .pressure: return .weather(.pressure)
            case .covidIncidence: return .covid(.incidence)
            case .waterLevel: return .water(.level)
            case .radiation: return .radiation(.total)
            case .pm10: return .particle(.pm10)
            case .pm25: return .particle(.pm25)
            case .no2: return .particle(.no2)
            case .o3: return .particle(.o3)
            case .brent: return .energy(.brent)
            case .wti: return .energy(.wti)
            case .lng: return .energy(.lng)
        }
    }

    static func values(of source: Source) -> [StatusBarValue] {
        return Self.allCases.filter { $0.source == source }
    }
}

/// Which values the status item shows. Modelled on senor-particle's `StatusBarDisplayPreferences`: at most two, in the order they were
/// ticked, stored as their raw values so an unknown one from a later version is simply skipped.
enum StatusBarPreferences {
    static let valuesKey = "statusBar.values"
    static let maximum = 2
    /// Shown when nothing is ticked, or nothing ticked can be shown: the temperature, as the status item always did.
    static let fallback: [StatusBarValue] = [.temperature]

    static func selection(defaults: UserDefaults = .standard) -> [StatusBarValue] {
        var values: [StatusBarValue] = []
        for raw in defaults.stringArray(forKey: Self.valuesKey) ?? [] {
            guard let value = StatusBarValue(rawValue: raw), values.contains(value) == false else { continue }
            values.append(value)
            if values.count == Self.maximum { break }
        }
        return values
    }

    static func setSelection(_ values: [StatusBarValue], defaults: UserDefaults = .standard) -> Void {
        var unique: [StatusBarValue] = []
        for value in values where unique.contains(value) == false {
            unique.append(value)
            if unique.count == Self.maximum { break }
        }
        if unique.isEmpty == true {
            defaults.removeObject(forKey: Self.valuesKey)
        }
        else {
            defaults.set(unique.map { $0.rawValue }, forKey: Self.valuesKey)
        }
    }

    /// Ticks a value, or unticks it when it is ticked. A third value is not added.
    static func toggle(_ value: StatusBarValue, defaults: UserDefaults = .standard) -> Void {
        var values = Self.selection(defaults: defaults)
        if let index = values.firstIndex(of: value) {
            values.remove(at: index)
        }
        else if values.count < Self.maximum {
            values.append(value)
        }
        Self.setSelection(values, defaults: defaults)
    }

    static func isSelected(_ value: StatusBarValue, defaults: UserDefaults = .standard) -> Bool {
        return Self.selection(defaults: defaults).contains(value)
    }

    /// Whether the checkbox can change: a ticked value can always be unticked, another only while fewer than two are ticked.
    static func canSelect(_ value: StatusBarValue, defaults: UserDefaults = .standard) -> Bool {
        let values = Self.selection(defaults: defaults)
        return values.contains(value) || values.count < Self.maximum
    }

    /// What the status item shows: the ticked values whose source is on, else the temperature.
    static func displayed(defaults: UserDefaults = .standard) -> [StatusBarValue] {
        let values = Self.selection(defaults: defaults).filter { $0.source.isAvailable(defaults: defaults) }
        return values.isEmpty == true ? Self.fallback : values
    }
}
