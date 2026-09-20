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
    private let measurementDistance: TimeInterval
    private let forecastDuration: TimeInterval

    init(networkManager: NetworkManager = .shared,
        nearestSensor: @escaping @Sendable () -> Bool = { return UserDefaults.standard.bool(forKey: "nearestLevelSensor") },
        sensorLimit: @escaping @Sendable () -> Int = { return SourcePreferences.sensorLimit(forKey: SourcePreferences.multiSensorLevelKey) },
        otherWaterways: @escaping @Sendable () -> Bool = {
            return UserDefaults.standard.bool(forKey: SourcePreferences.multiSensorLevelOtherWaterwaysKey)
        }) {
        self.networkManager = networkManager
        self.nearestSensor = nearestSensor
        self.sensorLimit = sensorLimit
        self.otherWaterways = otherWaterways
        self.measurementDistance = 900  // 15 minutes
        self.forecastDuration = 12 * 4 * self.measurementDistance  // 12 hours
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

    private func candidate(for station: Station) async throws -> SensorCandidate {
        var measurement: [ProcessValue<Dimension>] = []
        try Task.checkCancellation()
        if let level = try await self.fetchMeasurements(station: station) {
            try Task.checkCancellation()
            measurement.append(contentsOf: self.interpolateMeasurements(measurements: level, distance: self.measurementDistance))
            measurement.append(contentsOf: self.forecastMeasurements(data: measurement, duration: self.forecastDuration))
        }
        return SensorCandidate(
            id: station.id, name: station.name, location: station.location, customData: ["icon": "water.waves", "station": station.gauge],
            measurements: [.water(.level): measurement.sorted(by: { $0.timestamp < $1.timestamp })])
    }

    struct Station: ProcessLocatable {
        let id: String
        /// The waterway the gauge is on, so all the gauges of one river share it. `gauge` names the gauge itself.
        let name: String
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
                return Station(id: station.id, name: self.capitalizeGerman(text: station.name), gauge: station.gauge, location: station.location)
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
            let matching = stations.filter { $0.name.caseInsensitiveCompare(waterwayName) == .orderedSame }
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
                                if let name = water["longname"] as? String {
                                    let location = Location(latitude: latitude, longitude: longitude)
                                    let gauge = (item["longname"] as? String) ?? (item["shortname"] as? String) ?? name
                                    stations.append(Station(id: id, name: name, gauge: gauge, location: location))
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

    private func forecastMeasurements(data: [ProcessValue<Dimension>], duration: TimeInterval) -> [ProcessValue<Dimension>] {
        var forecastMeasurements: [ProcessValue<Dimension>] = []
        if data.count > 0 {
            let unit = data[0].value.unit
            let dataPoints = data.map { incidence in
                TimeSeriesPoint(timestamp: incidence.timestamp, value: incidence.value.value)
            }
            let predictor = ARIMAPredictor(parameters: ARIMAParameters(p: 2, d: 1, q: 1), interval: .quarterHourly)
            do {
                try predictor.addData(dataPoints)
                let prediction = try predictor.forecast(duration: duration)
                forecastMeasurements = prediction.forecasts.map { forecast in
//                    ProcessValue<Dimension>(
//                        value: Measurement(value: forecast.value, unit: unit), quality: .uncertain, timestamp: forecast.timestamp)
                    ProcessValue<Dimension>(
                        value: Measurement(value: 0.0, unit: unit), quality: .unknown, timestamp: forecast.timestamp)
                }
            }
            catch {
                print("Forecasting error: \(error)")
            }
        }
        return forecastMeasurements
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
