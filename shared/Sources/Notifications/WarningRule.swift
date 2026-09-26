import DoomKitProcess
import Foundation

/// A group of warnings with one switch: a source, except weather, which covers current weather and the forecast.
enum WarningFamily: String, CaseIterable, Sendable {
    case weather
    case hazards
    case level
    case radiation
    case particles
    case covid
    case energy
    case fuel

    var label: String {
        switch self {
            case .weather: return "Weather"
            case .hazards: return "Warnings"
            case .level: return "Water Level"
            case .radiation: return "Radiation"
            case .particles: return "Particulate Matter"
            case .covid: return "COVID-19"
            case .energy: return "Energy Prices"
            case .fuel: return "Fuel Prices"
        }
    }

    var icon: String {
        switch self {
            case .weather: return "cloud.sun"
            case .hazards: return "exclamationmark.triangle"
            case .level: return "water.waves"
            case .radiation: return "atom"
            case .particles: return "aqi.medium"
            case .covid: return "facemask"
            case .energy: return "chart.line.uptrend.xyaxis"
            case .fuel: return "fuelpump"
        }
    }

    /// Prices and COVID are something to opt into; the environmental families start on. The master switch starts off either way.
    var enabledByDefault: Bool {
        switch self {
            case .covid, .energy, .fuel: return false
            default: return true
        }
    }

    /// The family a rendered reading belongs to, read from its selectors. Polls have none: they are not warned about.
    static func of(_ reading: ProcessReading) -> WarningFamily? {
        guard let selector = reading.measurements.keys.first ?? reading.current.keys.first else { return nil }
        switch selector {
            case .weather, .forecast: return .weather
            case .water: return .level
            case .radiation: return .radiation
            case .particle: return .particles
            case .covid: return .covid
            case .energy: return .energy
            case .survey: return nil
        }
    }
}

/// How bad a reading is. Ordered, so a notice is due when the level rises.
enum WarningLevel: Int, Comparable, Codable, Sendable {
    case normal = 0
    case warning = 1
    case critical = 2

    var label: String {
        switch self {
            case .normal: return "normal"
            case .warning: return "warning"
            case .critical: return "critical"
        }
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

/// Which side of a limit is bad.
enum WarningDirection: Sendable {
    /// At or above the limit, as for heat or a pollutant.
    case above
    /// At or below the limit, as for frost.
    case below
}

/// One measurement with a warning and a critical limit the user can change. Level and hazards have no rule here: level compares each gauge
/// against its own marks, and hazards against a severity.
struct WarningRule: Identifiable {
    let id: String
    let family: WarningFamily
    /// What the limit is about, as the notice names it: "Heat", "PM10".
    let label: String
    /// The selectors whose current value counts.
    let current: [ProcessSelector]
    /// A forecast series whose next 24 hours count as well, so a notice can come before the weather does.
    let forecast: ProcessSelector?
    let direction: WarningDirection
    /// The unit the limits are stored in. Readings in another unit of the same dimension are converted to it. Nil for fuel prices, which are
    /// plain euros per litre.
    let unit: Dimension?
    let symbol: String
    let defaultWarning: Double
    let defaultCritical: Double
    /// Where the default limits come from, for the settings footnote.
    let basis: String
    /// The values the settings accept.
    let range: ClosedRange<Double>
    /// Decimals shown for a limit.
    let fractionDigits: Int

    static let catalogue: [WarningRule] = [
        WarningRule(
            id: "weather.heat", family: .weather, label: "Heat", current: [.weather(.apparentTemperature)],
            forecast: .forecast(.apparentTemperature), direction: .above, unit: UnitTemperature.celsius, symbol: "°C", defaultWarning: 32,
            defaultCritical: 38, basis: "Felt temperature. The DWD warns of strong heat stress from 32 °C and extreme heat stress from 38 °C.",
            range: -50 ... 60, fractionDigits: 0),
        WarningRule(
            id: "weather.frost", family: .weather, label: "Frost", current: [.weather(.temperature)], forecast: .forecast(.temperature),
            direction: .below, unit: UnitTemperature.celsius, symbol: "°C", defaultWarning: 0, defaultCritical: -10,
            basis: "Air temperature at or below the limit. The DWD warns of frost below 0 °C and severe frost below −10 °C.",
            range: -50 ... 60, fractionDigits: 0),
        WarningRule(
            id: "weather.gust", family: .weather, label: "Wind Gusts", current: [.weather(.windGust)], forecast: .forecast(.windGust),
            direction: .above, unit: UnitSpeed.kilometersPerHour, symbol: "km/h", defaultWarning: 65, defaultCritical: 90,
            basis: "The DWD calls gusts from 65 km/h storm gusts and from 90 km/h severe storm gusts.", range: 0 ... 300, fractionDigits: 0),
        WarningRule(
            id: "weather.rain", family: .weather, label: "Heavy Rain", current: [.weather(.precipitationIntensity)],
            forecast: .forecast(.precipitationAmount), direction: .above, unit: UnitLength.millimeters, symbol: "mm/h", defaultWarning: 15,
            defaultCritical: 25, basis: "Rain in one hour. The DWD warns of heavy rain from 15 mm and of severe heavy rain from 25 mm.",
            range: 0 ... 200, fractionDigits: 0),
        WarningRule(
            id: "particle.pm10", family: .particles, label: "PM10", current: [.particle(.pm10)], forecast: nil, direction: .above,
            unit: UnitConcentrationMass.microgramsPerCubicMeter, symbol: "µg/m³", defaultWarning: 50, defaultCritical: 100,
            basis: "The UBA air quality index rates PM10 poor from 50 µg/m³ and very poor from 100 µg/m³.", range: 0 ... 2000,
            fractionDigits: 0),
        WarningRule(
            id: "particle.pm25", family: .particles, label: "PM2.5", current: [.particle(.pm25)], forecast: nil, direction: .above,
            unit: UnitConcentrationMass.microgramsPerCubicMeter, symbol: "µg/m³", defaultWarning: 25, defaultCritical: 50,
            basis: "The UBA air quality index rates PM2.5 poor from 25 µg/m³ and very poor from 50 µg/m³.", range: 0 ... 2000,
            fractionDigits: 0),
        WarningRule(
            id: "particle.no2", family: .particles, label: "Nitrogen Dioxide", current: [.particle(.no2)], forecast: nil, direction: .above,
            unit: UnitConcentrationMass.microgramsPerCubicMeter, symbol: "µg/m³", defaultWarning: 100, defaultCritical: 200,
            basis: "The UBA air quality index rates NO2 poor from 100 µg/m³ and very poor from 200 µg/m³.", range: 0 ... 2000,
            fractionDigits: 0),
        WarningRule(
            id: "particle.o3", family: .particles, label: "Ozone", current: [.particle(.o3)], forecast: nil, direction: .above,
            unit: UnitConcentrationMass.microgramsPerCubicMeter, symbol: "µg/m³", defaultWarning: 180, defaultCritical: 240,
            basis: "The EU information threshold for ozone is 180 µg/m³ and its alert threshold 240 µg/m³, which the UBA index rates poor and very poor.",
            range: 0 ... 2000, fractionDigits: 0),
        WarningRule(
            id: "radiation.total", family: .radiation, label: "Dose Rate", current: [.radiation(.total)], forecast: nil, direction: .above,
            unit: UnitRadiation.microsieverts, symbol: "µSv/h", defaultWarning: 0.5, defaultCritical: 1.0,
            basis: "The natural background in Germany is 0.05 to 0.2 µSv/h, and rain can briefly double it, so the default sits above that.",
            range: 0 ... 1000, fractionDigits: 2),
        WarningRule(
            id: "covid.incidence", family: .covid, label: "Incidence", current: [.covid(.incidence)], forecast: nil, direction: .above,
            unit: UnitIncidence.casesPer100k, symbol: "per 100k", defaultWarning: 100, defaultCritical: 200,
            basis: "New cases per 100,000 people in seven days, for the reporting district.", range: 0 ... 100_000, fractionDigits: 0),
        WarningRule(
            id: "energy.brent", family: .energy, label: "Brent Crude", current: [.energy(.brent)], forecast: nil, direction: .above,
            unit: UnitOilPrice.usDollarsPerBarrel, symbol: "$/bbl", defaultWarning: 100, defaultCritical: 130,
            basis: "The daily spot price.", range: 0 ... 1000, fractionDigits: 0),
        WarningRule(
            id: "energy.wti", family: .energy, label: "WTI Crude", current: [.energy(.wti)], forecast: nil, direction: .above,
            unit: UnitOilPrice.usDollarsPerBarrel, symbol: "$/bbl", defaultWarning: 95, defaultCritical: 125,
            basis: "The daily spot price.", range: 0 ... 1000, fractionDigits: 0),
        WarningRule(
            id: "energy.lng", family: .energy, label: "EU LNG", current: [.energy(.lng)], forecast: nil, direction: .above,
            unit: UnitGasPrice.eurosPerMegawattHour, symbol: "€/MWh", defaultWarning: 60, defaultCritical: 100,
            basis: "ACER's daily assessment.", range: 0 ... 1000, fractionDigits: 0),
        WarningRule(
            id: "fuel.price", family: .fuel, label: "Fuel Price", current: [], forecast: nil, direction: .above, unit: nil, symbol: "€/l",
            defaultWarning: 2.00, defaultCritical: 2.20,
            basis: "The cheapest open station for the fuel and radius chosen under Energy. A notice means even that one is dear.",
            range: 0 ... 10, fractionDigits: 2),
    ]

    static func rules(for family: WarningFamily) -> [WarningRule] {
        return Self.catalogue.filter { $0.family == family }
    }

    /// A value in the rule's unit, written the way the settings write it.
    func format(_ value: Double) -> String {
        return String(format: "%.\(self.fractionDigits)f %@", value, self.symbol)
    }
}
