import Compression
import DoomKitNetwork
import DoomKitServices
import DoomKitTools
import DoomKitProcess
import DoomKitLocation
import Foundation

class LevelController: ProcessController {
    private let networkManager: NetworkManager
    private let nearestSensor: @Sendable () -> Bool
    private let sensorLimit: @Sendable () -> Int
    private let otherWaterways: @Sendable () -> Bool
    private let showForecasts: @Sendable () -> Bool
    private let measurementDistance: TimeInterval

    init(networkManager: NetworkManager = .shared,
        nearestSensor: @escaping @Sendable () -> Bool = { return UserDefaults.standard.bool(forKey: SourcePreferences.nearestLevelSensorKey) },
        sensorLimit: @escaping @Sendable () -> Int = { return SourcePreferences.sensorLimit(forKey: SourcePreferences.multiSensorLevelKey) },
        otherWaterways: @escaping @Sendable () -> Bool = {
            return UserDefaults.standard.bool(forKey: SourcePreferences.multiSensorLevelOtherWaterwaysKey)
        },
        showForecasts: @escaping @Sendable () -> Bool = { return SourcePreferences.forecastsVisible(.level) }) {
        self.networkManager = networkManager
        self.nearestSensor = nearestSensor
        self.sensorLimit = sensorLimit
        self.otherWaterways = otherWaterways
        self.showForecasts = showForecasts
        self.measurementDistance = 900  // 15 minutes
    }

    /// The gauge series come from separate requests, so this many are fetched at a time.
    static let fetchConcurrency = 2

    /// Gauges further away than this are not considered. It is more than the distance from List to Oberstdorf (960km).
    private static let maximumDistance = Measurement(value: 1000.0, unit: UnitLength.kilometers)

    func refreshData(for location: Location) async throws -> [ProcessSensor] {
        try Task.checkCancellation()
        let nearestStations = try await self.fetchNearestStations(location: location, limit: self.sensorLimit())
        try Task.checkCancellation()
        trace.debug("Nearest stations: \(nearestStations)")
        let candidates = try await nearestStations.concurrentCompactMap(limit: Self.fetchConcurrency) { station in
            return try await self.candidate(for: station)
        }
        return try await SensorCandidate.sensors(from: candidates, near: location)
    }

    /// Internal rather than private so a test can pin which of the two names ends up where.
    func candidate(for station: Station) async throws -> SensorCandidate {
        var measurement: [ProcessValue<Dimension>] = []
        try Task.checkCancellation()
        let showForecasts = self.showForecasts()
        async let pendingCharacteristics = self.fetchCharacteristics(station: station, includeForecast: showForecasts)
        let level = try await self.fetchMeasurements(station: station)
        if let level {
            try Task.checkCancellation()
            measurement.append(contentsOf: self.interpolateMeasurements(measurements: level, distance: self.measurementDistance))
        }
        // The sensor is named after its gauge, as every other source is named after its station. The waterway is what a level chart is
        // titled with, and the gauge's flood marks are what its warnings compare against; neither fits the standard interface, so both
        // travel in customData. A gauge that publishes no marks, or a failed request, simply leaves the key out.
        var customData: [String: Any] = ["icon": "water.waves", "waterway": station.waterway]
        let characteristics = await pendingCharacteristics
        if let marks = characteristics.marks, marks.isEmpty == false {
            customData["marks"] = marks
        }
        // Only a gauge that lists a forecast is asked for one: most have none, and asking would cost each of them a request and a 404.
        var forecasts: [ProcessSelector: ProcessForecast] = [:]
        if showForecasts == true, characteristics.hasForecast == true {
            try Task.checkCancellation()
            if let data = try? await LevelService.fetchForecast(for: station.id, networkManager: self.networkManager),
                let forecast = Self.parseForecast(data: data)
            {
                forecasts[.water(.level)] = forecast
            }
        }
        // Where PEGELONLINE has no forecast, which is most gauges and every one in Berlin, the app estimates one.
        if showForecasts == true, forecasts.isEmpty == true, let level, let estimate = Self.estimate(from: level) {
            forecasts[.water(.level)] = estimate
        }
        try Task.checkCancellation()
        return SensorCandidate(
            id: station.id, name: station.gauge, location: station.location, customData: customData,
            measurements: [.water(.level): measurement.sorted(by: { $0.timestamp < $1.timestamp })], forecasts: forecasts)
    }

    struct Station: ProcessLocatable {
        let id: String
        /// The waterway the gauge is on, so all the gauges of one river share it.
        let waterway: String
        /// The gauge itself, which is what the sensor is named after.
        let gauge: String
        let location: Location
    }

    /// The gauges to report, nearest first. By default these are the gauges on the nearest natural waterway; when there is none, or the
    /// `nearestSensor` preference is set, they are simply the nearest gauges.
    func fetchNearestStations(location: Location, limit: Int = ProcessSensor.maximumPerSource) async throws -> [Station] {
        var nearestStations: [Station] = []
        try Task.checkCancellation()
        if let data = try await LevelService.fetchStations(networkManager: self.networkManager) {
            try Task.checkCancellation()
            let stations = try Self.parseStations(from: data)
            var waterwayName: String? = nil
            if self.nearestSensor() == false {
                waterwayName = Self.nearestNaturalWaterwayName(location: location, radius: Self.waterwaySearchRadius)
                if let waterwayName = waterwayName {
                    trace.debug("Nearest natural waterway: \(waterwayName)")
                }
            }
            let selected = Self.selectStations(
                from: stations, near: location, waterwayName: waterwayName, limit: limit, otherWaterways: self.otherWaterways())
            nearestStations = selected.map { station in
                // Only the waterway is re-cased here. A gauge such as BERLIN-MÜHLENDAMM UP needs the hyphen and the suffix kept, which
                // capitalizeGerman does not do; SensorHeaderView.displayName handles gauges instead.
                return Station(
                    id: station.id, waterway: self.capitalizeGerman(text: station.waterway), gauge: station.gauge,
                    location: station.location)
            }
            if nearestStations.isEmpty == true {
                trace.error("No station found")
            }
        }
        return nearestStations
    }

    /// The gauges to report. Normally all of them follow one rule: the nearest gauges on the waterway, or the nearest overall. With
    /// `otherWaterways` only the first does; the rest are the nearest remaining gauges, whatever waterway they are on. They come after the
    /// first, so one of them can be nearer than it when it is on another waterway.
    static func selectStations(from stations: [Station], near location: Location, waterwayName: String?, limit: Int, otherWaterways: Bool = false) -> [Station] {
        if otherWaterways == false || limit <= 1 {
            return Self.selectStationsOnWaterway(from: stations, near: location, waterwayName: waterwayName, limit: limit)
        }
        var selected = Self.selectStationsOnWaterway(from: stations, near: location, waterwayName: waterwayName, limit: 1)
        if let first = selected.first {
            let others = stations.filter { $0.id != first.id }
            selected.append(contentsOf: Self.nearestStations(stations: others, location: location, limit: limit - 1))
        }
        return selected
    }

    private static func selectStationsOnWaterway(from stations: [Station], near location: Location, waterwayName: String?, limit: Int) -> [Station] {
        var selected: [Station] = []
        if let waterwayName = waterwayName {
            // Only the gauges of that waterway: mixing in gauges of other rivers would break the order by distance along one water body.
            let matching = stations.filter { $0.waterway.caseInsensitiveCompare(waterwayName) == .orderedSame }
            selected = Self.nearestStations(stations: matching, location: location, limit: limit)
            if selected.isEmpty == true {
                trace.warning("No stations found for waterway \(waterwayName), falling back to nearest stations")
            }
        }
        // Waterway matching is optional context. The official gauge data
        // remains usable when no natural waterway is found nearby.
        if selected.isEmpty == true {
            selected = Self.nearestStations(stations: stations, location: location, limit: limit)
        }
        return selected
    }

    private static func parseStations(from data: Data) throws -> [Station] {
        var stations: [Station] = []
        if let json = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) as? [[String: Any]] {
            for item in json {
                if let id = item["uuid"] as? String {
                    if let latitude = item["latitude"] as? Double {
                        if let longitude = item["longitude"] as? Double {
                            if let water = item["water"] as? [String: Any] {
                                if let waterway = water["longname"] as? String {
                                    let location = Location(latitude: latitude, longitude: longitude)
                                    let gauge = (item["longname"] as? String) ?? (item["shortname"] as? String) ?? waterway
                                    stations.append(Station(id: id, waterway: waterway, gauge: gauge, location: location))
                                }
                            }
                        }
                    }
                }
            }
        }
        return stations
    }

    private static func nearestStations(stations: [Station], location: Location, limit: Int) -> [Station] {
        let inRange = stations.filter { haversineDistance(location_0: $0.location, location_1: location) < Self.maximumDistance }
        return sortByDistance(inRange, from: location, limit: limit)
    }

    // The federal waterway network (VerkNet-BWaStr, Bundesamt für Kartographie und
    // Geodäsie's sibling agency GDWS) has no natural/artificial classification of its
    // own, but PEGELONLINE's own waterway names already separate named canals from the
    // natural river they branch off (e.g. "LANDWEHRKANAL" is its own name, distinct from
    // "SPREE-ODER-WASSERSTRASSE", even though it's officially a sub-segment of the same
    // Bundeswasserstraße). `BundeswasserstrassenNetz.json.zlib` is a one-time-curated
    // crosswalk from each of PEGELONLINE's waterway names to its real polyline geometry
    // and a natural/artificial flag, built from that dataset — see AGENTS.md.
    static let waterwaySearchRadius = 10000.0

    private struct RawWaterwayEntry: Decodable {
        let isNatural: Bool
        let lines: [[[Double]]]
    }

    private struct Waterway {
        let isNatural: Bool
        let lines: [[Location]]
    }

    private static let waterways: [String: Waterway] = {
        guard let url = Bundle.main.url(forResource: "BundeswasserstrassenNetz.json", withExtension: "zlib") else {
            trace.error("Bundled federal waterway network resource not found")
            return [:]
        }
        do {
            let compressed = try Data(contentsOf: url)
            let data = try (compressed as NSData).decompressed(using: .zlib) as Data
            let raw = try JSONDecoder().decode([String: RawWaterwayEntry].self, from: data)
            return raw.mapValues { entry in
                let lines = entry.lines.map { line in
                    line.compactMap { point -> Location? in
                        guard point.count >= 2 else { return nil }
                        return Location(latitude: point[0], longitude: point[1])
                    }
                }
                return Waterway(isNatural: entry.isNatural, lines: lines)
            }
        }
        catch {
            trace.error("Failed to load bundled federal waterway network: \(error.localizedDescription)")
            return [:]
        }
    }()

    private static func nearestNaturalWaterwayName(location: Location, radius: Double) -> String? {
        var nearestName: String? = nil
        var minDistance = Measurement(value: 1000.0, unit: UnitLength.kilometers)  // This is more than the distance from List to Oberstdorf (960km)
        for (name, waterway) in Self.waterways where waterway.isNatural {
            for line in waterway.lines {
                guard let nearest = PolygonProximityCalculator.nearestPointOnPolyline(from: location, to: line) else { continue }
                let distance = Measurement(value: nearest.distance, unit: UnitLength.meters)
                if distance < minDistance {
                    minDistance = distance
                    nearestName = name
                }
            }
        }
        guard let nearestName, minDistance.converted(to: .meters).value <= radius else { return nil }
        return nearestName
    }

    private func fetchMeasurements(station: Station) async throws -> [ProcessValue<Dimension>]? {
        var measurements: [ProcessValue<Dimension>]? = nil
        try Task.checkCancellation()
        if let data = try await LevelService.fetchMeasurements(for: station.id, networkManager: self.networkManager) {
            try Task.checkCancellation()
            measurements = try Self.parseLevels(data: data)
        }
        return measurements
    }

    /// The gauge's characteristic values and whether it has a forecast, never throwing: marks only add warnings and a forecast only adds a
    /// line, so a failure must not cost the gauge its readings.
    private func fetchCharacteristics(station: Station, includeForecast: Bool) async -> (marks: [String: Double]?, hasForecast: Bool) {
        guard let data = try? await LevelService.fetchCharacteristics(for: station.id, includeForecast: includeForecast, networkManager: self.networkManager)
        else { return (nil, false) }
        return (Self.parseMarks(data: data), Self.hasForecast(data: data))
    }

    /// The app's own estimate for a gauge without a published forecast. A tidal gauge, one whose last days the tides explain, follows
    /// its tide for the next day at the quarter hour; any other follows a damped trend on the hour for the next 12 hours, which on a canal
    /// held by locks is nearly flat. Not continued when the gauge has not reported for six hours.
    static func estimate(from raw: [ProcessValue<Dimension>], now: Date = .now) -> ProcessForecast? {
        let maximumAge: TimeInterval = 6 * 3600
        let tide = ForecastRequest(step: 900, horizon: 96, maximumGap: 6 * 3600)
        let periods = HarmonicModel.tidalPeriods.map { $0 * 4 }
        let points = raw.filter { $0.quality == .good }.map {
            TimeSeriesPoint(timestamp: $0.timestamp, value: $0.value.converted(to: UnitLength.meters).value)
        }
        if let values = try? Forecaster.prepare(points, request: tide).values, HarmonicModel.detect(values, periods: periods) == true {
            return SeriesEstimate.make(from: raw, model: HarmonicModel(periods: periods), request: tide, maximumAge: maximumAge, now: now)
        }
        return SeriesEstimate.make(
            from: raw, model: DampedTrendModel(), request: ForecastRequest(step: 3600, horizon: 12, maximumGap: 6 * 3600),
            maximumAge: maximumAge, now: now)
    }

    /// Whether the station's time series include the water level forecast, `WV`. Only listed when the request asked for forecasts.
    static func hasForecast(data: Data) -> Bool {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let series = json["timeseries"] as? [[String: Any]]
        else { return false }
        return series.contains { $0["shortname"] as? String == "WV" }
    }

    /// PEGELONLINE's water level forecast as a provider forecast, in metres like the readings: the value, the 10 and 90 percentiles as
    /// the band where the forecast has them (so far only the Oder's), and the run's time as `issued`. The run turns from `forecast` to
    /// `estimate` after the first days, the forecaster's own rougher extension; where it does is kept as `customData["estimateFrom"]`.
    static func parseForecast(data: Data) -> ProcessForecast? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return nil }
        var points: [ProcessForecast.Point] = []
        var issued: Date?
        var estimateFrom: Date?
        for item in json {
            guard let centimetres = item["value"] as? Double, let string = item["timestamp"] as? String,
                let timestamp = Self.parseTimestamp(string: string)
            else { continue }
            let value = Measurement<Dimension>(value: centimetres / 100, unit: UnitLength.meters)
            let lower = (item["percentile10"] as? Double).map { $0 / 100 }
            let upper = (item["percentile90"] as? Double).map { $0 / 100 }
            let hasBand = lower != nil && upper != nil
            points.append(ProcessForecast.Point(timestamp: timestamp, value: value, lower: hasBand ? lower : nil, upper: hasBand ? upper : nil))
            if let initialized = (item["initialized"] as? String).flatMap({ Self.parseTimestamp(string: $0) }) {
                issued = max(issued ?? initialized, initialized)
            }
            if item["type"] as? String == "estimate" {
                estimateFrom = min(estimateFrom ?? timestamp, timestamp)
            }
        }
        guard points.isEmpty == false else { return nil }
        return ProcessForecast(
            origin: .provider("PEGELONLINE"), issued: issued, points: points, customData: estimateFrom.map { ["estimateFrom": $0] })
    }

    /// The characteristic values of the station's W series, keyed by their PEGELONLINE short names (`MHW`, `M_I`, `HSW` and so on), in
    /// metres like the readings. PEGELONLINE gives them in centimetres above the gauge zero, the same reference as the readings.
    static func parseMarks(data: Data) -> [String: Double]? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let series = json["timeseries"] as? [[String: Any]],
            let level = series.first(where: { $0["shortname"] as? String == "W" }),
            let values = level["characteristicValues"] as? [[String: Any]]
        else { return nil }
        var marks: [String: Double] = [:]
        for value in values {
            guard let name = value["shortname"] as? String, let centimetres = value["value"] as? Double else { continue }
            marks[name] = centimetres / 100
        }
        return marks
    }

    private static func parseTimestamp(string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: string)
    }

    private static func parseLevels(data: Data) throws -> [ProcessValue<Dimension>]? {
        if let json = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) as? [[String: Any]] {
            var levels: [ProcessValue<Dimension>] = []
            for item in json {
                if let value = item["value"] as? Double {
                    if let timestamp = item["timestamp"] as? String {
                        if let date = Self.parseTimestamp(string: timestamp) {
                            let level = Measurement<Dimension>(value: value, unit: UnitLength.centimeters)
                            levels.append(ProcessValue<Dimension>(value: level.converted(to: UnitLength.meters), quality: .good, timestamp: date))
                        }
                    }
                }
            }
            return levels
        }
        return nil
    }

    private func interpolateMeasurements(measurements: [ProcessValue<Dimension>], distance: TimeInterval) -> [ProcessValue<Dimension>] {
        var interpolatedMeasurement: [ProcessValue<Dimension>] = []
        if let start = measurements.first?.timestamp, let end = measurements.last?.timestamp {
            var current = start
            if var last = measurements.first {
                while current <= end {
                    if let match = measurements.first(where: { $0.timestamp == current }) {
                        last = match
                        interpolatedMeasurement.append(match)
                    }
                    else {
                        interpolatedMeasurement
                            .append(
                                ProcessValue<Dimension>(
                                    value: Measurement(value: last.value.value, unit: last.value.unit), quality: .uncertain,
                                    timestamp: current))
                    }
                    current = current.addingTimeInterval(distance)
                }
            }
        }
        return interpolatedMeasurement
    }

    private func capitalizeGerman(text: String) -> String {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        let properCasedWords = words.map { word -> String in
            guard !word.isEmpty else { return word }

            let firstChar = String(word.prefix(1)).uppercased()
            let restOfWord = String(word.dropFirst()).lowercased()

            return firstChar + restOfWord
        }
        return properCasedWords.joined(separator: " ")
    }
}
