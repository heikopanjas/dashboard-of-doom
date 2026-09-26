import DoomKitProcess
import Foundation

/// How one measurement of one sensor stands against its limits, with the words a notice would use. Every measurement that could be judged
/// gets one, the normal ones included, because a reading back to normal is what re-arms its notice.
struct WarningAssessment: Equatable {
    /// What a notice is about, and so what it replaces: the rule and, when the source has several sensors, the sensor.
    let key: String
    /// Which series judged it. Current weather and the forecast share a key but are separate inputs, so a frost the forecast announced
    /// does not notify again when it arrives, and a mild afternoon does not re-arm a frost still forecast for the night.
    let input: String
    let family: WarningFamily
    let level: WarningLevel
    let title: String
    let body: String
}

/// A gauge's warning and critical marks, with the PEGELONLINE short name each one came from.
struct LevelMarks: Equatable {
    struct Mark: Equatable {
        let name: String
        let value: Double
    }

    let warning: Mark
    let critical: Mark?
}

/// Pure judgements of readings against the limits. Nothing here posts, stores or reads the switches; `WarningNotifier` does that.
enum WarningEvaluator {
    /// How far ahead a forecast counts.
    static let forecastWindow: TimeInterval = 24 * 60 * 60

    static func level(_ value: Double, limits: WarningLimits, direction: WarningDirection) -> WarningLevel {
        switch direction {
            case .above:
                if value >= limits.critical { return .critical }
                if value >= limits.warning { return .warning }
            case .below:
                if value <= limits.critical { return .critical }
                if value <= limits.warning { return .warning }
        }
        return .normal
    }

    // MARK: - Readings

    static func assessments(readings: [ProcessReading], defaults: UserDefaults = .standard, now: Date = .now) -> [WarningAssessment] {
        var assessments: [WarningAssessment] = []
        for reading in readings {
            guard let family = WarningFamily.of(reading) else { continue }
            if family == .level {
                if let assessment = Self.levelAssessment(reading: reading) { assessments.append(assessment) }
                continue
            }
            for rule in WarningRule.rules(for: family) {
                let limits = WarningPreferences.limits(for: rule, defaults: defaults)
                if let assessment = Self.currentAssessment(rule: rule, limits: limits, reading: reading) {
                    assessments.append(assessment)
                }
                if let assessment = Self.forecastAssessment(rule: rule, limits: limits, reading: reading, now: now) {
                    assessments.append(assessment)
                }
            }
        }
        return assessments
    }

    /// The transformer's current value, which already leaves out values of unknown quality, so ARIMA placeholders never count.
    private static func currentAssessment(rule: WarningRule, limits: WarningLimits, reading: ProcessReading) -> WarningAssessment? {
        for selector in rule.current {
            guard let current = reading.current[selector], let value = Self.value(current.value, in: rule) else { continue }
            let level = Self.level(value, limits: limits, direction: rule.direction)
            return WarningAssessment(
                key: Self.key(rule.id, reading: reading), input: "current", family: rule.family, level: level,
                title: Self.title(rule.label, level: level),
                body: "\(Self.place(of: reading)): \(rule.format(value)). \(Self.limitSentence(level, limits: limits, rule: rule))")
        }
        return nil
    }

    /// The worst hour of the next day. It keeps that hour, so the notice can say when.
    private static func forecastAssessment(rule: WarningRule, limits: WarningLimits, reading: ProcessReading, now: Date) -> WarningAssessment? {
        guard let selector = rule.forecast, let series = reading.measurements[selector] else { return nil }
        let end = now.addingTimeInterval(Self.forecastWindow)
        var worst: (value: Double, timestamp: Date)?
        for measurement in series where measurement.timestamp > now && measurement.timestamp <= end && measurement.quality != .unknown {
            guard let value = Self.value(measurement.value, in: rule) else { continue }
            let isWorse: Bool
            if let worst {
                isWorse = rule.direction == .above ? value > worst.value : value < worst.value
            }
            else {
                isWorse = true
            }
            if isWorse { worst = (value, measurement.timestamp) }
        }
        guard let worst else { return nil }
        let level = Self.level(worst.value, limits: limits, direction: rule.direction)
        return WarningAssessment(
            key: Self.key(rule.id, reading: reading), input: "forecast", family: rule.family, level: level,
            title: Self.title(rule.label, level: level),
            body: "\(Self.place(of: reading)): \(rule.format(worst.value)) expected \(Self.when(worst.timestamp, now: now)). "
                + Self.limitSentence(level, limits: limits, rule: rule))
    }

    // MARK: - Level

    /// The warning mark is the first flood reporting stage where the state publishes one, else the mean high water. The critical mark is the
    /// first of the second stage, the highest navigable level and the highest level on record that lies above it: the highest navigable
    /// level can sit below the mean high water (Celle: 3.10 m against 4.12 m), so no single mark can be the second one.
    static func levelMarks(_ marks: [String: Double]) -> LevelMarks? {
        guard let warning = ["M_I", "MHW"].lazy.compactMap({ name in marks[name].map { LevelMarks.Mark(name: name, value: $0) } }).first
        else { return nil }
        let critical = ["M_II", "HSW", "HHW"].lazy.compactMap { name in marks[name].map { LevelMarks.Mark(name: name, value: $0) } }
            .first { $0.value > warning.value }
        return LevelMarks(warning: warning, critical: critical)
    }

    /// What a mark is, in words.
    static func markLabel(_ name: String) -> String {
        switch name {
            case "M_I": return "flood stage I"
            case "M_II": return "flood stage II"
            case "M_III": return "flood stage III"
            case "MHW": return "mean high water"
            case "HSW": return "highest navigable level"
            case "HHW": return "highest level on record"
            default: return name
        }
    }

    static func marks(of sensor: ProcessSensor) -> LevelMarks? {
        guard let marks = sensor.customData?["marks"] as? [String: Double] else { return nil }
        return Self.levelMarks(marks)
    }

    private static func levelAssessment(reading: ProcessReading) -> WarningAssessment? {
        guard let marks = Self.marks(of: reading.sensor), let current = reading.current[.water(.level)] else { return nil }
        let value = current.value.converted(to: UnitLength.meters).value
        var level = WarningLevel.normal
        var mark = marks.warning
        if let critical = marks.critical, value >= critical.value {
            level = .critical
            mark = critical
        }
        else if value >= marks.warning.value {
            level = .warning
        }
        let verb = level == .normal ? "below" : "at or above"
        return WarningAssessment(
            key: Self.key("level.marks", reading: reading), input: "current", family: .level, level: level,
            title: Self.title("High Water", level: level),
            body: String(format: "%@: %.2f m, %@ %@ at %.2f m.", reading.sensor.name, value, verb, Self.markLabel(mark.name), mark.value))
    }

    // MARK: - Hazards

    /// One per warning, keyed by the NINA id, so each new warning can notify once.
    static func assessments(hazards: [Hazard], defaults: UserDefaults = .standard) -> [WarningAssessment] {
        let limits = WarningPreferences.hazardLimits(defaults: defaults)
        return hazards.map { hazard in
            let level: WarningLevel = hazard.severity >= limits.critical ? .critical : hazard.severity >= limits.warning ? .warning : .normal
            return WarningAssessment(
                key: "hazard.\(hazard.id)", input: "current", family: .hazards, level: level, title: hazard.headline,
                body: "\(hazard.severity.label) · \(hazard.areaLabel)")
        }
    }

    // MARK: - Fuel

    /// The cheapest open station selling the fuel, the nearer one of two at the same price. A notice means even that one is dear.
    static func assessments(stations: [FuelStation], fuel: FuelStation.Fuel, radius: Double, defaults: UserDefaults = .standard)
        -> [WarningAssessment]
    {
        guard let rule = WarningRule.rules(for: .fuel).first else { return [] }
        let selling = stations.filter { $0.isOpen == true && $0.price(for: fuel) != nil }
        let cheapest = selling.min { first, second in
            let one = first.price(for: fuel) ?? 0
            let other = second.price(for: fuel) ?? 0
            return one == other ? first.distance < second.distance : one < other
        }
        guard let cheapest, let price = cheapest.price(for: fuel) else { return [] }
        let limits = WarningPreferences.limits(for: rule, defaults: defaults)
        let level = Self.level(price, limits: limits, direction: rule.direction)
        return [
            WarningAssessment(
                key: rule.id, input: "current", family: .fuel, level: level, title: Self.title(rule.label, level: level),
                body: String(format: "Cheapest %@ within %.0f km: %.3f €/l at %@. ", fuel.label, radius, price, cheapest.name)
                    + Self.limitSentence(level, limits: limits, rule: rule))
        ]
    }

    // MARK: - Helpers

    /// A reading in the rule's unit, or nil when it cannot be one. Rain is the exception to plain conversion: WeatherKit gives the current
    /// intensity as a speed, the height of water falling per second, which becomes millimetres per hour.
    static func value(_ measurement: Measurement<Dimension>, in rule: WarningRule) -> Double? {
        guard let unit = rule.unit else { return measurement.value }
        if type(of: measurement.unit) == type(of: unit) {
            return measurement.converted(to: unit).value
        }
        if unit == UnitLength.millimeters, measurement.unit is UnitSpeed {
            return measurement.converted(to: UnitSpeed.metersPerSecond).value * 3_600_000
        }
        return nil
    }

    private static func key(_ id: String, reading: ProcessReading) -> String {
        guard let sourceID = reading.sensor.sourceID else { return id }
        return "\(id).\(sourceID)"
    }

    private static func place(of reading: ProcessReading) -> String {
        return reading.sensor.placemark ?? reading.sensor.name
    }

    private static func title(_ label: String, level: WarningLevel) -> String {
        return level == .critical ? "\(label): critical" : "\(label) warning"
    }

    private static func limitSentence(_ level: WarningLevel, limits: WarningLimits, rule: WarningRule) -> String {
        let limit = level == .critical ? limits.critical : limits.warning
        return "The \(level == .critical ? "critical" : "warning") limit is \(rule.format(limit))."
    }

    /// "at 03:00", or "tomorrow at 03:00" for a time past midnight.
    private static func when(_ date: Date, now: Date) -> String {
        let time = date.formatted(date: .omitted, time: .shortened)
        return Calendar.current.isDate(date, inSameDayAs: now) ? "at \(time)" : "tomorrow at \(time)"
    }
}
