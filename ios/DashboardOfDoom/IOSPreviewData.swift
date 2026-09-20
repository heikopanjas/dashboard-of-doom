#if DEBUG
import DoomKitLocation
import DoomKitProcess
import Foundation

/// Deterministic, offline UI-test data. Only enabled by an explicit Debug launch argument.
enum IOSPreviewData {
    static var isEnabled: Bool {
        return ProcessInfo.processInfo.arguments.contains("--ui-fixture")
    }

    static var pointCount: Int {
        return ProcessInfo.processInfo.arguments.contains("--poi-10000") == true ? 10_000 : 2_000
    }

    static func points(category: PointOfInterestCategory) -> [PointOfInterest] {
        guard let categoryIndex = PointOfInterestCategory.allCases.firstIndex(of: category) else { return [] }
        var result: [PointOfInterest] = []
        for index in stride(from: categoryIndex, to: Self.pointCount, by: PointOfInterestCategory.allCases.count) {
            let latitude = 52.51889 + Double((index * 37) % 1000 - 500) / 20_000
            let longitude = 13.36528 + Double((index * 61) % 1000 - 500) / 12_000
            result.append(
                PointOfInterest(
                    category: category, elementType: "node", elementID: Int64(index), name: "Fixture \(index)",
                    location: Location(latitude: latitude, longitude: longitude)))
        }
        return result
    }

    @MainActor
    static func populate(_ runtime: IOSAppRuntime) {
        let entries: [(ProcessPresenter, ProcessSelector, Dimension, Double, String)] = [
            (runtime.weather, .weather(.temperature), UnitTemperature.celsius, 22, "thermometer"),
            (runtime.forecast, .forecast(.temperature), UnitTemperature.celsius, 22, "cloud.sun"),
            (runtime.covid, .covid(.incidence), UnitIncidence.casesPer100k, 12.3, "cross.case"),
            (runtime.levels, .water(.level), UnitLength.meters, 2.73, "water.waves"),
            (runtime.radiation, .radiation(.total), UnitRadiation.microsieverts, 0.08, "atom"),
            (runtime.particles, .particle(.pm10), UnitConcentrationMass.microgramsPerCubicMeter, 18, "aqi.medium"),
            (runtime.surveys, .survey(.fascists), UnitPercentage.percent, 20, "chart.bar")
        ]
        // Hour-aligned, so the forecast strip labels read 14:00 rather than 14:37.
        let date = Date.round(from: Date.now, strategy: .previousHour) ?? Date.now
        for (index, entry) in entries.enumerated() {
            let (presenter, selector, unit, value, icon) = entry
            let location = Location(latitude: 52.51889 + Double(index % 3) * 0.012, longitude: 13.36528 + Double(index / 3) * 0.015)
            let measurements = (0 ..< 48).map { hour in
                return ProcessValue<Dimension>(
                    value: Measurement(value: value * (1 + 0.1 * sin(Double(hour))), unit: unit),
                    quality: .good, timestamp: date.addingTimeInterval(Double(hour - 24) * 3600))
            }
            let sensor = ProcessSensor(
                name: "HKW fixture", location: location, placemark: "HKW, Berlin",
                customData: ["icon": icon, "label": "HKW"], measurements: [selector: measurements], timestamp: date)
            presenter.replace(readings: [
                ProcessReading(
                    sensor: sensor, measurements: [selector: measurements], current: [selector: measurements[24]],
                    faceplate: [selector: String(format: "%.2f %@", value, unit.symbol)], range: [selector: 0 ... max(value * 1.5, 1)],
                    trend: [selector: "arrow.right"])
            ])
            if presenter !== runtime.forecast { MapPresenter.shared.updateRegion(for: presenter.id, with: location) }
        }
        // A level sensor is named after its waterway and carries the gauge separately; the others are named after their station.
        Self.populateAdditionalSensors(
            runtime.levels, selector: .water(.level), unit: UnitLength.meters, value: 2.73, date: date,
            stations: ["BERLIN-MÜHLENDAMM OP", "BERLIN-CHARLOTTENBURG UP"], namedAfterStation: false)
        Self.populateAdditionalSensors(
            runtime.radiation, selector: .radiation(.total), unit: UnitRadiation.microsieverts, value: 0.08, date: date,
            stations: ["Berlin-Marzahn", "Berlin-Tegel"], namedAfterStation: true)
        Self.populateAdditionalSensors(
            runtime.particles, selector: .particle(.pm10), unit: UnitConcentrationMass.microgramsPerCubicMeter, value: 18, date: date,
            stations: ["Berlin Neukölln", "Berlin Wedding"], namedAfterStation: true)
        Self.populateForecastStrip(runtime.forecast, date: date)
        Self.populateConditions(runtime.weather, date: date)
        runtime.hazards.publish(hazards: Self.hazards(sent: date), timestamp: date)
    }

    /// Per-hour condition symbols and a rain chance series, the two things the
    /// forecast strip shows beyond the temperature the loop above provides.
    @MainActor
    private static func populateForecastStrip(_ presenter: ProcessPresenter, date: Date) {
        let icons = ["sun.max", "cloud.sun", "cloud", "cloud.rain"]
        guard let temperature = presenter.measurements[.forecast(.temperature)] else { return }
        let withIcons = temperature.enumerated().map { index, value in
            return ProcessValue<Dimension>(
                value: value.value, customData: ["icon": icons[index % icons.count]], quality: value.quality,
                timestamp: value.timestamp)
        }
        let chance = temperature.enumerated().map { index, value in
            return ProcessValue<Dimension>(
                value: Measurement(value: Double((index * 17) % 100), unit: UnitPercentage.percent), quality: value.quality,
                timestamp: value.timestamp)
        }
        Self.amend(
            presenter, measurements: [.forecast(.temperature): withIcons, .forecast(.precipitationChance): chance],
            current: [.forecast(.temperature): withIcons[24]])
    }

    /// Appends one further sensor per station behind the nearest reading, each a little further away and with its own series, the way a
    /// source that found several stations reports them. Like the real ones they have no placemark.
    @MainActor
    private static func populateAdditionalSensors(
        _ presenter: ProcessPresenter, selector: ProcessSelector, unit: Dimension, value: Double, date: Date, stations: [String], namedAfterStation: Bool
    ) -> Void {
        guard let nearest = presenter.readings.first else { return }
        var readings = [nearest]
        for (offset, station) in stations.enumerated() {
            let position = offset + 1
            let level = value * (1 + Double(position) * 0.15)
            let series = (0 ..< 48).map { hour in
                return ProcessValue<Dimension>(
                    value: Measurement(value: level * (1 + 0.1 * sin(Double(hour + position))), unit: unit),
                    quality: .good, timestamp: date.addingTimeInterval(Double(hour - 24) * 3600))
            }
            let location = Location(latitude: nearest.sensor.location.latitude + Double(position) * 0.01, longitude: nearest.sensor.location.longitude)
            var customData: [String: Any] = ["icon": nearest.sensor.customData?["icon"] ?? "questionmark.circle"]
            if namedAfterStation == false {
                customData["station"] = station
            }
            let sensor = ProcessSensor(
                name: namedAfterStation == true ? station : nearest.sensor.name, location: location, placemark: nil, customData: customData,
                measurements: [selector: series], timestamp: date, sourceID: "fixture-\(position)-\(station)", distance: 800 + Double(position) * 2_400)
            readings.append(
                ProcessReading(
                    sensor: sensor, measurements: [selector: series], current: [selector: series[24]],
                    faceplate: [selector: String(format: "%.2f %@", level, unit.symbol)], range: [selector: 0 ... max(level * 1.5, 1)],
                    trend: [selector: "arrow.right"]))
        }
        presenter.replace(readings: readings)
    }

    /// Merges extra series into the nearest reading, keeping its sensor and everything else already rendered.
    @MainActor
    private static func amend(
        _ presenter: ProcessPresenter, measurements: [ProcessSelector: [ProcessValue<Dimension>]], current: [ProcessSelector: ProcessValue<Dimension>]
    ) -> Void {
        guard let reading = presenter.readings.first else { return }
        presenter.replace(readings: [
            ProcessReading(
                sensor: reading.sensor, measurements: reading.measurements.merging(measurements) { $1 },
                current: reading.current.merging(current) { $1 }, faceplate: reading.faceplate, range: reading.range, trend: reading.trend)
        ])
    }

    /// Single samples for the conditions row. Pressure is in millibars so the
    /// hPa conversion runs; wind is already km/h.
    @MainActor
    private static func populateConditions(_ presenter: ProcessPresenter, date: Date) {
        let samples: [(ProcessSelector, Dimension, Double)] = [
            (.weather(.apparentTemperature), UnitTemperature.celsius, 20.4),
            (.weather(.humidity), UnitPercentage.percent, 64),
            (.weather(.windSpeed), UnitSpeed.kilometersPerHour, 12),
            (.weather(.windGust), UnitSpeed.kilometersPerHour, 28),
            (.weather(.pressure), UnitPressure.millibars, 1013),
        ]
        var measurements: [ProcessSelector: [ProcessValue<Dimension>]] = [:]
        var current: [ProcessSelector: ProcessValue<Dimension>] = [:]
        for (selector, unit, value) in samples {
            let sample = ProcessValue<Dimension>(value: Measurement(value: value, unit: unit), quality: .good, timestamp: date)
            measurements[selector] = [sample]
            current[selector] = sample
        }
        Self.amend(presenter, measurements: measurements, current: current)
    }

    private static func hazards(sent: Date) -> [Hazard] {
        let hkw = Location(latitude: 52.51889, longitude: 13.36528)
        return [
            Hazard(
                id: "fixture-dwd", feed: .dwd, event: "STURMBÖEN", headline: "Amtliche WARNUNG vor STURMBÖEN",
                description: "Es treten Sturmböen mit Geschwindigkeiten um 70 km/h auf.",
                instruction: "Frei stehende Objekte sichern; im Freien auf herabfallende Gegenstände achten.",
                severity: .moderate, sent: sent, expires: sent.addingTimeInterval(86_400), areaDescription: "Berlin",
                location: hkw, distance: 0, placemark: nil),
            Hazard(
                id: "fixture-mowas", feed: .mowas, event: "Gefahreninformation",
                headline: "Bakteriologische Beeinträchtigung des Trinkwassers",
                description: "Das Trinkwasser ist vor dem Gebrauch abzukochen.", instruction: nil, severity: .minor,
                sent: sent.addingTimeInterval(-3600), expires: nil, areaDescription: "Potsdam",
                location: Location(latitude: 52.4009, longitude: 13.0591), distance: 12_000, placemark: nil),
            Hazard(
                id: "fixture-katwarn", feed: .katwarn, event: "Großbrand", headline: "Großbrand in Spandau",
                description: "Starke Rauchentwicklung.", instruction: "Fenster und Türen geschlossen halten.",
                severity: .severe, sent: sent.addingTimeInterval(-1800), expires: sent.addingTimeInterval(7200),
                areaDescription: "Berlin-Spandau", location: Location(latitude: 52.5352, longitude: 13.1995),
                distance: 9_000, placemark: nil),
        ]
    }
}
#endif
