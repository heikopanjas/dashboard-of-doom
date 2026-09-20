import DoomKitServices
import DoomKitTools
import DoomKitProcess
import DoomKitLocation
import Foundation

class RadiationController: ProcessController {
    private let measurementDistance: TimeInterval
    private let forecastDuration: TimeInterval
    private let sensorLimit: @Sendable () -> Int

    init(sensorLimit: @escaping @Sendable () -> Int = { return SourcePreferences.sensorLimit(forKey: SourcePreferences.multiSensorRadiationKey) }) {
        self.sensorLimit = sensorLimit
        self.measurementDistance = 3600  // 1 hour
        self.forecastDuration = 1 * 24 * self.measurementDistance  // 1 day
    }

    /// The station series come from separate requests, so this many are fetched at a time.
    static let fetchConcurrency = 2

    func refreshData(for location: Location) async throws -> [ProcessSensor] {
        try Task.checkCancellation()
        let nearestStations = try await Self.fetchNearestStations(location: location, limit: self.sensorLimit())
        try Task.checkCancellation()
        let candidates = try await nearestStations.concurrentCompactMap(limit: Self.fetchConcurrency) { station in
            return try await self.candidate(for: station)
        }
        return try await SensorCandidate.sensors(from: candidates, near: location)
    }

    private func candidate(for station: Station) async throws -> SensorCandidate {
        var measurement: [ProcessValue<Dimension>] = []
        try Task.checkCancellation()
        if let radiation = try await Self.fetchMeasurements(station: station) {
            try Task.checkCancellation()
            measurement.append(contentsOf: self.interpolateMeasurements(measurements: radiation, distance: self.measurementDistance))
            measurement.append(contentsOf: self.forecastMeasurements(data: measurement, duration: self.forecastDuration))
        }
        return SensorCandidate(
            id: station.id, name: station.name, location: station.location, customData: ["icon": "atom"],
            measurements: [.radiation(.total): measurement.sorted(by: { $0.timestamp < $1.timestamp })])
    }

    struct Station: ProcessLocatable {
        let id: String
        let name: String
        let location: Location
    }

    private static func fetchNearestStations(location: Location, limit: Int) async throws -> [Station] {
        var nearestStations: [Station] = []
        try Task.checkCancellation()
        if let data = try await RadiationService.fetchStations() {
            try Task.checkCancellation()
            let stations = try await Self.parseStations(from: data)
            nearestStations = Self.nearestStations(stations: stations, location: location, limit: limit)
        }
        return nearestStations
    }

    private static func parseStations(from data: Data) async throws -> [Station] {
        var stations: [Station] = []
        if let json = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) as? [String: Any] {
            if let features = json["features"] as? [[String: Any]] {
                for feature in features {
                    if let geometry = feature["geometry"] as? [String: Any], let coordinates = geometry["coordinates"] as? [Double] {
                        let location = Location(latitude: coordinates[1], longitude: coordinates[0])
                        if let properties = feature["properties"] as? [String: Any] {
                            if let id = properties["kenn"] as? String {
                                if let name = properties["name"] as? String {
                                    let siteStatus = properties["site_status"] as? Int
                                    if siteStatus == 1 {
                                        stations.append(Station(id: id, name: name, location: location))
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        return stations
    }

    static func nearestStations(stations: [Station], location: Location, limit: Int) -> [Station] {
        return sortByDistance(stations, from: location, limit: limit)
    }

    private static func fetchMeasurements(station: Station) async throws -> [ProcessValue<Dimension>]? {
        var radiation: [ProcessValue<Dimension>]? = nil
        try Task.checkCancellation()
        if let data = try await RadiationService.fetchMeasurements(for: station.id) {
            try Task.checkCancellation()
            radiation = try Self.parseRadiation(data: data)
        }
        return radiation
    }

    private static func parseRadiation(data: Data) throws -> [ProcessValue<Dimension>] {
        var measurements: [ProcessValue<Dimension>] = []
        if let json = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) as? [String: Any] {
            if let features = json["features"] as? [[String: Any]] {
                for feature in features {
                    if let properties = feature["properties"] as? [String: Any] {
                        if let dateString = properties["end_measure"] as? String {
                            let isoFormatter = ISO8601DateFormatter()
                            if let timestamp = isoFormatter.date(from: dateString) {
                                if let value = properties["value"] as? Double, let validated = properties["validated"] as? Int {
                                    let measurement = ProcessValue<Dimension>(
                                        value: Measurement(value: value, unit: UnitRadiation.microsieverts),
                                        quality: (validated == 1) ? .good : .uncertain, timestamp: timestamp)
                                    measurements.append(measurement)
                                }
                            }
                        }
                    }
                }
            }
        }
        return measurements
    }

    private func interpolateMeasurements(measurements: [ProcessValue<Dimension>], distance: TimeInterval) -> [ProcessValue<Dimension>] {
        var interpolated: [ProcessValue<Dimension>] = []
        if let start = measurements.first?.timestamp, let end = measurements.last?.timestamp {
            let unit = measurements[0].value.unit
            var current = start
            if var last = measurements.first {
                while current <= end {
                    if let match = measurements.first(where: { $0.timestamp == current }) {
                        last = match
                        interpolated.append(match)
                    }
                    else {
                        interpolated
                            .append(
                                ProcessValue<Dimension>(
                                    value: Measurement(value: last.value.value, unit: unit), quality: .uncertain,
                                    timestamp: current))
                    }
                    current = current.addingTimeInterval(distance)
                }
            }
        }
        return interpolated
    }

    private func forecastMeasurements(data: [ProcessValue<Dimension>], duration: TimeInterval) -> [ProcessValue<Dimension>] {
        var forecast: [ProcessValue<Dimension>] = []
        if data.count > 0 {
            let unit = data[0].value.unit
            let dataPoints = data.map { incidence in
                TimeSeriesPoint(timestamp: incidence.timestamp, value: incidence.value.value)
            }
            let predictor = ARIMAPredictor(parameters: ARIMAParameters(p: 2, d: 1, q: 1), interval: .hourly)
            do {
                try predictor.addData(dataPoints)
                let prediction = try predictor.forecast(duration: duration)
                forecast = prediction.forecasts.map { forecast in
//                    ProcessValue<Dimension>(
//                        value: Measurement(value: forecast.value, unit: unit), quality: .uncertain, timestamp: forecast.timestamp)
                    ProcessValue<Dimension>(
                        value: Measurement(value: 0.0, unit: unit), quality: .unknown, timestamp: forecast.timestamp)
                }
            }
            catch {
                trace.error("Forecasting error: %@", error.localizedDescription)
            }
        }
        return forecast
    }
}
