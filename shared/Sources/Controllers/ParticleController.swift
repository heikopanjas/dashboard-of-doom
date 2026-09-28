import DoomKitServices
import DoomKitTools
import DoomKitProcess
import DoomKitLocation
import Foundation

class ParticleController: ProcessController {
    private let measurementDuration: TimeInterval
    private let forecastDuration: TimeInterval
    #if os(iOS)
    private static let smoothingFactor = 13
    #else
    private static let smoothingFactor = 4
    #endif

    /// The station series come from separate requests, so this many are fetched at a time.
    static let fetchConcurrency = 2

    private let nearestSensor: @Sendable () -> Bool
    private let sensorLimit: @Sendable () -> Int
    private let showForecasts: @Sendable () -> Bool
    private let fetchForecast: @Sendable (_ code: String, _ from: Date, _ to: Date) async throws -> Data?

    /// UBA gives its times in CET all year, "date end (CET)" in the response's own legend, so they are read at UTC+1 and not in the
    /// device's time zone, which put every reading an hour early in summer.
    static let serviceTimeZone = TimeZone(secondsFromGMT: 3600)

    init(
        nearestSensor: @escaping @Sendable () -> Bool = { return UserDefaults.standard.bool(forKey: SourcePreferences.nearestParticleSensorKey) },
        sensorLimit: @escaping @Sendable () -> Int = { return SourcePreferences.sensorLimit(forKey: SourcePreferences.multiSensorParticlesKey) },
        showForecasts: @escaping @Sendable () -> Bool = { return SourcePreferences.forecastsVisible() },
        fetchForecast: @escaping @Sendable (_ code: String, _ from: Date, _ to: Date) async throws -> Data? = { code, from, to in
            return try await ParticleService.fetchForecasts(code: code, from: from, to: to)
        }
    ) {
        self.nearestSensor = nearestSensor
        self.sensorLimit = sensorLimit
        self.showForecasts = showForecasts
        self.fetchForecast = fetchForecast
        self.measurementDuration = 21 * 24 * 60 * 60  // 21 days
        self.forecastDuration = 7 * 24 * 60 * 60  // 7 days
    }

    func refreshData(for location: Location) async throws -> [ProcessSensor] {
        var data: [ProcessSensor] = []

        do {
            if let interval = Self.calculateMeasurementTimeInterval(span: self.measurementDuration) {
                try Task.checkCancellation()
                let results = await self.fetchStationResults(location: location, from: interval.from, to: interval.to)
                try Task.checkCancellation()
                let candidates = try await results.concurrentCompactMap(limit: Self.fetchConcurrency) { result in
                    return try await self.candidate(for: result, from: interval.from, to: interval.to)
                }
                // Without data for the nearest station nothing is published, so the last values stay, rather than showing a farther
                // station as if it were the nearest.
                if let first = results.first, candidates.first?.id == first.station.code {
                    data = try await SensorCandidate.sensors(from: candidates, near: location)
                }
            }
        }
        catch is CancellationError { throw CancellationError() }
        catch {
            guard Task.isCancelled == false else { throw CancellationError() }
            trace.error("Error refreshing particulate matter: %@", error.localizedDescription)
        }
        return data
    }

    /// One station's measurements and forecast, or nil when it has none. A failure drops that station only; a failed forecast only costs
    /// the forecast. Internal rather than private so a test can drive it with cached measurements.
    func candidate(for result: StationResult, from: Date, to: Date) async throws -> SensorCandidate? {
        do {
            try Task.checkCancellation()
            // Use cached measurements if available, otherwise fetch them
            var measurements: [ProcessSelector: [ProcessValue<Dimension>]]?
            if let cached = result.cachedMeasurements {
                trace.debug("Using cached measurements for station: \(result.station.code)")
                measurements = cached
            }
            else {
                measurements = try await Self.fetchMeasurements(station: result.station, from: from, to: to)
            }

            if let measurements = measurements {
                // Gap-filled and smoothed whether or not a forecast arrives: that used to happen only when the forecast request succeeded.
                let series = measurements.mapValues { self.interpolateMeasurement(measurements: $0) }
                var forecasts: [ProcessSelector: ProcessForecast] = [:]
                if self.showForecasts() == true, let interval = Self.calculateForecastTimeInterval(span: self.forecastDuration) {
                    try Task.checkCancellation()
                    if let data = try? await self.fetchForecast(result.station.code, interval.from, interval.to) {
                        // A pollutant the station does not measure has no chart to draw its forecast on.
                        forecasts = ((try? Self.parseForecasts(data: data)) ?? [:]).filter { series[$0.key] != nil }
                    }
                }
                try Task.checkCancellation()
                return SensorCandidate(
                    id: result.station.code, name: result.station.name, location: result.station.location,
                    customData: ["icon": "aqi.medium"], measurements: series, forecasts: forecasts)
            }
        }
        catch is CancellationError { throw CancellationError() }
        catch {
            guard Task.isCancelled == false else { throw CancellationError() }
            trace.error("Error refreshing station %@: %@", result.station.code, error.localizedDescription)
        }
        return nil
    }

    private func interpolateMeasurement(measurements: [ProcessValue<Dimension>]) -> [ProcessValue<Dimension>] {
        var interpolatedMeasurement: [ProcessValue<Dimension>] = []
        if let start = measurements.first?.timestamp, let end = measurements.last?.timestamp {
            let unit = measurements[0].value.unit
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
                                    value: Measurement(value: last.value.value, unit: unit), quality: .uncertain,
                                    timestamp: current))
                    }
                    current = current.addingTimeInterval(60 * 60)
                }
            }
        }
        let smoothed = gaussianSmoothing(data: interpolatedMeasurement.map { $0.value }, windowSize: 11, sigma: 2.3)
        return zip(interpolatedMeasurement, smoothed).map { original, measurement in
            return ProcessValue(value: measurement, customData: original.customData, quality: original.quality, timestamp: original.timestamp)
        }
    }

    private static func calculateMeasurementTimeInterval(span: TimeInterval) -> (from: Date, to: Date)? {
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour], from: Date.now)
        var adjustedComponents = components
        adjustedComponents.minute = 0  // Reset minutes to 0
        adjustedComponents.second = 0  // Reset seconds to 0
        if let to = Calendar.current.date(from: adjustedComponents) {
            let from = to.addingTimeInterval(-1 * span)  // rewind
            return (from, to)
        }
        return nil
    }

    private static func calculateForecastTimeInterval(span: TimeInterval) -> (from: Date, to: Date)? {
        if let next = Date.round(from: Date.now, strategy: .previousQuarterHour) {
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour], from: next)
            var adjustedComponents = components
            adjustedComponents.minute = 0  // Reset minutes to 0
            adjustedComponents.second = 0  // Reset seconds to 0
            if let from = Calendar.current.date(from: adjustedComponents) {
                let to = from.addingTimeInterval(span)  // forward
                return (from, to)
            }
        }
        return nil
    }

    struct Station: ProcessLocatable {
        let id: String
        let code: String
        let name: String
        let location: Location
    }

    struct StationResult {
        let station: Station
        let cachedMeasurements: [ProcessSelector: [ProcessValue<Dimension>]]?
    }

    private func fetchStationResults(location: Location, from: Date, to: Date) async -> [StationResult] {
        if Task.isCancelled == true {
            return []
        }
        var results: [StationResult] = []
        do {
            if let data = try await ParticleService.fetchStations(from: from, to: to) {
                if Task.isCancelled == true {
                    return []
                }
                let stations = sortByDistance(try await Self.parseStations(from: data), from: location)
                if Task.isCancelled == true {
                    return []
                }
                results = await Self.selectStations(from: stations, nearest: self.nearestSensor(), limit: self.sensorLimit()) { station in
                    return try? await Self.fetchMeasurements(station: station, from: from, to: to)
                }
            }
        }
        catch {
            if Task.isCancelled == true {
                return []
            }
            trace.error("Error fetching stations: %@", error.localizedDescription)
        }
        return results
    }

    private static func parseStations(from data: Data) async throws -> [Station] {
        var stations: [Station] = []
        if let json = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) as? [String: Any] {
            if let features = json["data"] as? [String: [Any]] {
                for (id, elements) in features {
                    if let code = elements[1] as? String, let name = elements[2] as? String {
                        if let longitudeString = elements[7] as? String, let latitudeString = elements[8] as? String {
                            if let longitude = Double(longitudeString), let latitude = Double(latitudeString) {
                                stations.append(
                                    Station(
                                        id: id, code: code, name: name,
                                        location: Location(latitude: Double(latitude), longitude: Double(longitude))))
                            }
                        }
                    }
                }
            }
        }
        return stations
    }

    /// How many stations are probed at once while looking for ones that report every relevant pollutant.
    static let probeConcurrency = 3

    /// The stations to report, nearest first, from `stations` ordered by distance.
    ///
    /// By default only stations that report every relevant pollutant are reported: stations are probed in order, as many at a time as are
    /// still missing, until `limit` qualify or none are left, so fewer than `limit` can come back. With `nearest` they are simply the nearest
    /// stations, whatever they report. When no station qualifies at all they are the nearest as well, so an outage of the measurement
    /// endpoint does not empty the tab. `probe` returns a station's measurements, or nil; a qualifying station carries what it returned so it
    /// is not fetched twice.
    static func selectStations(
        from stations: [Station], nearest: Bool, limit: Int,
        probe: @escaping (Station) async -> [ProcessSelector: [ProcessValue<Dimension>]]?
    ) async -> [StationResult] {
        let count = Swift.max(limit, 1)
        if nearest == false {
            var qualifying: [StationResult] = []
            var next = 0
            while next < stations.count && qualifying.count < count {
                if Task.isCancelled == true {
                    return []
                }
                // Only as many as are still missing, so a single station is still probed one at a time and nothing is fetched in vain.
                let batch = Array(stations[next ..< Swift.min(next + count - qualifying.count, stations.count)])
                next += batch.count
                let probed = (try? await batch.concurrentCompactMap(limit: Self.probeConcurrency) { station in
                    return await probe(station).map { (station, $0) }
                }) ?? []
                if Task.isCancelled == true {
                    return []
                }
                for (station, measurements) in probed where Self.stationHasRelevantMeasurements(measurements) == true {
                    trace.debug("Selected station \(station.code) with cached measurements")
                    qualifying.append(StationResult(station: station, cachedMeasurements: measurements))
                }
            }
            if qualifying.isEmpty == false {
                return qualifying
            }
        }
        if Task.isCancelled == true {
            return []
        }
        return stations.prefix(count).map { StationResult(station: $0, cachedMeasurements: nil) }
    }

    static func stationHasRelevantMeasurements(_ measurements: [ProcessSelector: [ProcessValue<Dimension>]]) -> Bool {
        let relevantSelectors: Set<ProcessSelector> = [
            .particle(.pm10), .particle(.pm25), .particle(.no2), .particle(.o3)
        ]
        return relevantSelectors.isSubset(of: Set(measurements.keys))
    }

    private static func fetchMeasurements(station: Station, from: Date, to: Date) async throws -> [ProcessSelector: [ProcessValue<Dimension>]]? {
        var measurements: [ProcessSelector: [ProcessValue<Dimension>]]? = nil
        do {
            try Task.checkCancellation()
            if let data = try await ParticleService.fetchMeasurements(code: station.code, from: from, to: to) {
                try Task.checkCancellation()
                if let json = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) as? [String: Any] {
                    if let features = json["data"] as? [String: Any] {
                        if let featureId = features.keys.first {
                            if let measurementSequence = features[featureId] as? [String: [Any]] {
                                for (_, measurementValues) in measurementSequence {
                                    if let measurementEnd = measurementValues[0] as? String {
                                        if let timestamp = Date.fromString(measurementEnd, format: "yyyy-MM-dd HH:mm:ss", timeZone: Self.serviceTimeZone) {
                                            for measurementItems in measurementValues[3...] {
                                                if let measurementItem = measurementItems as? [Any] {
                                                    if let componentId = measurementItem[0] as? Int {
                                                        if let selector = ProcessSelector.particle(from: componentId) {
                                                            if let unit = Self.selectMeasurementUnit(component: selector) {
                                                                if let value = measurementItem[1] as? Double {
                                                                    let measurement = ProcessValue<Dimension>(
                                                                        value: Measurement(value: value, unit: unit), quality: .good,
                                                                        timestamp: timestamp)
                                                                    if measurements == nil {
                                                                        measurements = [selector: [measurement]]
                                                                    }
                                                                    else if measurements?[selector] == nil {
                                                                        measurements?[selector] = [measurement]
                                                                    }
                                                                    else {
                                                                        measurements?[selector]?.append(measurement)
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        catch {
            trace.error("Error fetching measurements: %@", error.localizedDescription)
        }
        if measurements != nil {
            for (selector, values) in measurements! {
                measurements?[selector] = values.sorted(by: { $0.timestamp < $1.timestamp })
            }
        }
        return measurements
    }

    /// UBA's forecast for a station, one provider forecast per pollutant. A row is `[end, created, index, incomplete, [component, value,
    /// index, index decimal]...]` keyed by its start, all in CET; the value is taken at the end of its hour, as the measurements are.
    static func parseForecasts(data: Data) throws -> [ProcessSelector: ProcessForecast] {
        guard let json = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) as? [String: Any],
            let features = json["data"] as? [String: Any], let featureId = features.keys.first,
            let rows = features[featureId] as? [String: [Any]]
        else { return [:] }
        var points: [ProcessSelector: [ProcessForecast.Point]] = [:]
        var issued: Date?
        for (_, row) in rows where row.count > 4 {
            guard let end = row[0] as? String,
                let timestamp = Date.fromString(end, format: "yyyy-MM-dd HH:mm:ss", timeZone: Self.serviceTimeZone)
            else { continue }
            if let created = row[1] as? String, let date = Date.fromString(created, format: "yyyy-MM-dd HH:mm:ss", timeZone: Self.serviceTimeZone) {
                issued = max(issued ?? date, date)
            }
            for item in row[4...] {
                guard let item = item as? [Any], item.count > 1, let component = item[0] as? Int,
                    let selector = ProcessSelector.particle(from: component), let unit = Self.selectMeasurementUnit(component: selector),
                    let value = item[1] as? Double
                else { continue }
                points[selector, default: []].append(ProcessForecast.Point(timestamp: timestamp, value: Measurement(value: value, unit: unit)))
            }
        }
        return points.mapValues { ProcessForecast(origin: .provider("UBA"), issued: issued, points: $0) }
    }

    static private func selectMeasurementUnit(component: ProcessSelector) -> UnitConcentrationMass? {
        switch component {
            case .particle(.pm10):
                return UnitConcentrationMass.microgramsPerCubicMeter
            case .particle(.co):
                return UnitConcentrationMass.milligramsPerCubicMeter
            case .particle(.o3):
                return UnitConcentrationMass.microgramsPerCubicMeter
            case .particle(.so2):
                return UnitConcentrationMass.microgramsPerCubicMeter
            case .particle(.no2):
                return UnitConcentrationMass.microgramsPerCubicMeter
            case .particle(.lead):
                return UnitConcentrationMass.microgramsPerCubicMeter
            case .particle(.benzoapyrene):
                return UnitConcentrationMass.nanogramsPerCubicMeter
            case .particle(.benzene):
                return UnitConcentrationMass.microgramsPerCubicMeter
            case .particle(.pm25):
                return UnitConcentrationMass.microgramsPerCubicMeter
            case .particle(.arsenic):
                return UnitConcentrationMass.nanogramsPerCubicMeter
            case .particle(.cadmium):
                return UnitConcentrationMass.nanogramsPerCubicMeter
            case .particle(.nickel):
                return UnitConcentrationMass.nanogramsPerCubicMeter
            default:
                return nil
        }
    }
}
