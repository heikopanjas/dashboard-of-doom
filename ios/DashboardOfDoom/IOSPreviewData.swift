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
            presenter.sensor = ProcessSensor(
                name: "HKW fixture", location: location, placemark: "HKW, Berlin",
                customData: ["icon": icon, "label": "HKW"], measurements: [selector: measurements], timestamp: date)
            presenter.timestamp = date
            presenter.measurements = [selector: measurements]
            presenter.current = [selector: measurements[24]]
            presenter.faceplate = [selector: String(format: "%.2f %@", value, unit.symbol)]
            presenter.range = [selector: 0 ... max(value * 1.5, 1)]
            presenter.trend = [selector: "arrow.right"]
            if presenter !== runtime.forecast { MapPresenter.shared.updateRegion(for: presenter.id, with: location) }
        }
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
        presenter.measurements[.forecast(.temperature)] = withIcons
        presenter.measurements[.forecast(.precipitationChance)] = chance
        presenter.current[.forecast(.temperature)] = withIcons[24]
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
        for (selector, unit, value) in samples {
            let sample = ProcessValue<Dimension>(value: Measurement(value: value, unit: unit), quality: .good, timestamp: date)
            presenter.measurements[selector] = [sample]
            presenter.current[selector] = sample
        }
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
