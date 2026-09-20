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
    private let measurementDistance: TimeInterval
    private let forecastDuration: TimeInterval

    init(networkManager: NetworkManager = .shared,
        nearestSensor: @escaping @Sendable () -> Bool = { return UserDefaults.standard.bool(forKey: "nearestLevelSensor") }) {
        self.networkManager = networkManager
        self.nearestSensor = nearestSensor
        self.measurementDistance = 900  // 15 minutes
        self.forecastDuration = 12 * 4 * self.measurementDistance  // 12 hours
    }

    func refreshData(for location: Location) async throws -> [ProcessSensor] {
        var data: [ProcessSensor] = []

        try Task.checkCancellation()
        if let nearestStation = try await fetchNearestStation(location: location) {
            try Task.checkCancellation()
            trace.debug("Nearest station: \(nearestStation)")
            var measurements: [ProcessSelector: [ProcessValue<Dimension>]] = [:]
            try Task.checkCancellation()
            if let level = try await fetchMeasurements(station: nearestStation) {
                try Task.checkCancellation()
                var measurement: [ProcessValue<Dimension>] = []
                measurement.append(contentsOf: self.interpolateMeasurements(measurements: level, distance: self.measurementDistance))
                measurement.append(contentsOf: self.forecastMeasurements(data: measurement, duration: self.forecastDuration))
                measurements[.water(.level)] = measurement.sorted(by: { $0.timestamp < $1.timestamp })
            }
            try Task.checkCancellation()
            if let placemark = await GeocodingService.reverseGeocodeLocation(location: nearestStation.location) {
                try Task.checkCancellation()
                let sensor = ProcessSensor(
                    name: nearestStation.name, location: nearestStation.location, placemark: placemark, customData: ["icon": "water.waves"],
                    measurements: measurements,
                    timestamp: Date.now)
                data.append(sensor)
            }
        }
        return data
    }

    struct Station {
        let id: String
        let name: String
        let location: Location
    }

    func fetchNearestStation(location: Location) async throws -> Station? {
        var nearestStation: Station? = nil
        try Task.checkCancellation()
        if let data = try await LevelService.fetchStations(networkManager: self.networkManager) {
            try Task.checkCancellation()
            if let stations = try Self.parseStations(from: data) {
                if self.nearestSensor() == true {
                    if let station = Self.nearestStation(stations: stations, location: location) {
                        nearestStation = Station(
                            id: station.id, name: self.capitalizeGerman(text: station.name), location: station.location)
                    }
                }
                else {
                    if let waterwayName = Self.nearestNaturalWaterwayName(location: location, radius: Self.waterwaySearchRadius) {
                        trace.debug("Nearest natural waterway: \(waterwayName)")
                        let matchingStations = stations.filter { $0.name.caseInsensitiveCompare(waterwayName) == .orderedSame }
                        if let matchedStation = Self.nearestStation(stations: matchingStations, location: location) {
                            nearestStation = Station(
                                id: matchedStation.id, name: self.capitalizeGerman(text: waterwayName), location: matchedStation.location)
                        }
                        else {
                            trace.warning("No stations found for waterway \(waterwayName), falling back to nearest station")
                        }
                        if let nearestStation = nearestStation {
                            trace.debug("Nearest station: \(nearestStation)")
                        }
                        else {
                            trace.error("No station found")
                        }
                    }
                }
                // Waterway matching is optional context. The official gauge data
                // remains usable when no natural waterway is found nearby.
                if nearestStation == nil, let station = Self.nearestStation(stations: stations, location: location) {
                    try Task.checkCancellation()
                    nearestStation = Station(id: station.id, name: self.capitalizeGerman(text: station.name), location: station.location)
                }
            }
        }
        return nearestStation
    }

    private static func parseStations(from data: Data) throws -> [Station]? {
        if let json = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) as? [[String: Any]] {
            var stations: [Station] = []
            for item in json {
                if let id = item["uuid"] as? String {
                    if let latitude = item["latitude"] as? Double {
                        if let longitude = item["longitude"] as? Double {
                            if let water = item["water"] as? [String: Any] {
                                if let name = water["longname"] as? String {
                                    let location = Location(latitude: latitude, longitude: longitude)
                                    stations.append(Station(id: id, name: name, location: location))
                                }
                            }
                        }
                    }
                }
            }
            return stations
        }
        return nil
    }

    private static func nearestStation(stations: [Station], location: Location) -> Station? {
        var nearestStation: Station? = nil
        var minDistance = Measurement(value: 1000.0, unit: UnitLength.kilometers)  // This is more than the distance from List to Oberstdorf (960km)
        for station in stations {
            let distance = haversineDistance(location_0: station.location, location_1: location)
            if distance < minDistance {
                minDistance = distance
                nearestStation = station
            }
        }
        return nearestStation
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
