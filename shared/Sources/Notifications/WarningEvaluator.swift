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
        // Read here rather than trusted from the readings: a forecast fetched before its switch went off must not warn after it.
        let levelForecasts = SourcePreferences.forecastsVisible(.level, defaults: defaults)
        let particleForecasts = SourcePreferences.forecastsVisible(.particles, defaults: defaults)
        var assessments: [WarningAssessment] = []
        for reading in readings {
            guard let family = WarningFamily.of(reading) else { continue }
            if family == .level {
                if let assessment = Self.levelAssessment(reading: reading) { assessments.append(assessment) }
                if levelForecasts == true, let assessment = Self.levelForecastAssessment(reading: reading, now: now) {
                    assessments.append(assessment)
                }
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
                // Only the particle rules let a provider's forecast count.
                if family == .particles, particleForecasts == true,
                    let assessment = Self.providerForecastAssessment(rule: rule, limits: limits, reading: reading, now: now)
                {
                    assessments.append(assessment)
                }
            }
        }
        return assessments
    }

    /// The transformer's current value, which already leaves out values of unknown quality.
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
        let samples = series.filter { $0.quality != .unknown }.compactMap { measurement in
            Self.value(measurement.value, in: rule).map { (value: $0, timestamp: measurement.timestamp) }
        }
        guard let worst = Self.worst(samples, direction: rule.direction, now: now) else { return nil }
        let level = Self.level(worst.value, limits: limits, direction: rule.direction)
        return WarningAssessment(
            key: Self.key(rule.id, reading: reading), input: "forecast", family: rule.family, level: level,
            title: Self.title(rule.label, level: level),
            body: "\(Self.place(of: reading)): \(rule.format(worst.value)) expected \(Self.when(worst.timestamp, now: now)). "
                + Self.limitSentence(level, limits: limits, rule: rule))
    }

    /// The worst point of a provider's forecast within the next day, for the rules that let one count. It shares the rule's key with the
    /// current value as another input, like the weather forecast, so an announced value does not notify again when it arrives.
    private static func providerForecastAssessment(
        rule: WarningRule, limits: WarningLimits, reading: ProcessReading, now: Date
    ) -> WarningAssessment? {
        guard rule.providerForecast == true else { return nil }
        for selector in rule.current {
            guard let forecast = reading.forecasts[selector], case .provider(let provider) = forecast.origin else { continue }
            let samples = forecast.points.compactMap { point in
                Self.value(point.value, in: rule).map { (value: $0, timestamp: point.timestamp) }
            }
            guard let worst = Self.worst(samples, direction: rule.direction, now: now) else { continue }
            let level = Self.level(worst.value, limits: limits, direction: rule.direction)
            return WarningAssessment(
                key: Self.key(rule.id, reading: reading), input: "forecast", family: rule.family, level: level,
                title: Self.title(rule.label, level: level),
                body: "\(Self.place(of: reading)): \(rule.format(worst.value)) expected \(Self.when(worst.timestamp, now: now)) (\(provider) forecast). "
                    + Self.limitSentence(level, limits: limits, rule: rule))
        }
        return nil
    }

    /// The worst of `samples` after now and within the forecast window: the highest for a limit above, the lowest for one below.
    private static func worst(
        _ samples: [(value: Double, timestamp: Date)], direction: WarningDirection, now: Date
    ) -> (value: Double, timestamp: Date)? {
        let end = now.addingTimeInterval(Self.forecastWindow)
        var worst: (value: Double, timestamp: Date)?
        for sample in samples where sample.timestamp > now && sample.timestamp <= end {
            if let current = worst, (direction == .above ? sample.value <= current.value : sample.value >= current.value) { continue }
            worst = sample
        }
        return worst
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
        let (level, mark) = Self.level(value, marks: marks)
        let verb = level == .normal ? "below" : "at or above"
        return WarningAssessment(
            key: Self.key("level.marks", reading: reading), input: "current", family: .level, level: level,
            title: Self.title("High Water", level: level),
            body: String(format: "%@: %.2f m, %@ %@ at %.2f m.", reading.sensor.name, value, verb, Self.markLabel(mark.name), mark.value))
    }

    /// The highest point of the gauge's official forecast within the next day, against the same marks and under the same key as its
    /// current level, as another input. The app's own estimates never count.
    private static func levelForecastAssessment(reading: ProcessReading, now: Date) -> WarningAssessment? {
        guard let marks = Self.marks(of: reading.sensor), let forecast = reading.forecasts[.water(.level)],
            case .provider(let provider) = forecast.origin
        else { return nil }
        let samples = forecast.points.map { (value: $0.value.converted(to: UnitLength.meters).value, timestamp: $0.timestamp) }
        guard let highest = Self.worst(samples, direction: .above, now: now) else { return nil }
        let (level, mark) = Self.level(highest.value, marks: marks)
        let verb = level == .normal ? "below" : "at or above"
        return WarningAssessment(
            key: Self.key("level.marks", reading: reading), input: "forecast", family: .level, level: level,
            title: Self.title("High Water", level: level),
            body: String(
                format: "%@: %.2f m expected %@, %@ %@ at %.2f m (%@ forecast).", reading.sensor.name, highest.value,
                Self.when(highest.timestamp, now: now), verb, Self.markLabel(mark.name), mark.value, provider))
    }

    /// Where a level stands against a gauge's marks, and the mark that decides it: the critical one when it is reached, else the warning.
    private static func level(_ value: Double, marks: LevelMarks) -> (WarningLevel, LevelMarks.Mark) {
        if let critical = marks.critical, value >= critical.value {
            return (.critical, critical)
        }
        return (value >= marks.warning.value ? .warning : .normal, marks.warning)
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

    /// The cheapest station selling the fuel, the nearer one of two at the same price, open ones only while the user's Open Stations Only
    /// setting is on, as on the map. A notice means even that one is dear.
    static func assessments(
        stations: [FuelStation], fuel: FuelStation.Fuel, radius: Double, openOnly: Bool = true, defaults: UserDefaults = .standard
    ) -> [WarningAssessment] {
        guard let rule = WarningRule.rules(for: .fuel).first else { return [] }
        let selling = stations.filter { (openOnly == false || $0.isOpen == true) && $0.price(for: fuel) != nil }
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
