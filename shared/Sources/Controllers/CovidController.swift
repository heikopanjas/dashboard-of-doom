import DoomKitServices
import DoomKitTools
import DoomKitProcess
import DoomKitLocation
import Foundation

class CovidController: ProcessController {
    private let measurementDistance: TimeInterval
    private let measurementDuration: Double
    private let forecastDuration: TimeInterval

    init() {
        self.measurementDistance = 24 * 60 * 60  // 1 day
        self.measurementDuration = 167.0  // 167 days
        self.forecastDuration = Double(Int(self.measurementDuration / 4)) * self.measurementDistance
    }

    func refreshData(for location: Location) async throws -> [ProcessSensor] {
        var data: [ProcessSensor] = []
        try Task.checkCancellation()
        if let district = try await self.fetchDistrict(for: location) {
            try Task.checkCancellation()
            var measurements: [ProcessSelector: [ProcessValue<Dimension>]] = [:]

            // Launch all fetches in parallel
            async let incidenceData = self.fetchIncidence(for: district)
            async let casesData = self.fetchCases(for: district)
            async let deathsData = self.fetchDeaths(for: district)
            async let recoveredData = self.fetchRecovered(for: district)

            // Await all results together
            try Task.checkCancellation()
            let (incidence, cases, deaths, recovered) = try await (incidenceData, casesData, deathsData, recoveredData)
            try Task.checkCancellation()

            if let incidence = incidence {
                var measurement: [ProcessValue<Dimension>] = []
                measurement.append(contentsOf: self.interpolateMeasurements(measurements: incidence, distance: self.measurementDistance))
                measurement.append(contentsOf: self.forecastMeasurements(data: incidence, duration: self.forecastDuration))
                measurements[.covid(.incidence)] = measurement.sorted(by: { $0.timestamp < $1.timestamp })
            }
            if let cases = cases {
                var measurement: [ProcessValue<Dimension>] = []
                measurement.append(contentsOf: self.interpolateMeasurements(measurements: cases, distance: self.measurementDistance))
                measurement.append(contentsOf: self.forecastMeasurements(data: cases, duration: self.forecastDuration))
                measurements[.covid(.cases)] = measurement.sorted(by: { $0.timestamp < $1.timestamp })
            }
            if let deaths = deaths {
                var measurement: [ProcessValue<Dimension>] = []
                measurement.append(contentsOf: self.interpolateMeasurements(measurements: deaths, distance: self.measurementDistance))
                measurement.append(contentsOf: self.forecastMeasurements(data: deaths, duration: self.forecastDuration))
                measurements[.covid(.deaths)] = measurement.sorted(by: { $0.timestamp < $1.timestamp })
            }
            if let recovered = recovered {
                var measurement: [ProcessValue<Dimension>] = []
                measurement.append(contentsOf: self.interpolateMeasurements(measurements: recovered, distance: self.measurementDistance))
                measurement.append(contentsOf: self.forecastMeasurements(data: recovered, duration: self.forecastDuration))
                measurements[.covid(.recovered)] = measurement.sorted(by: { $0.timestamp < $1.timestamp })
            }
            try Task.checkCancellation()
            if let placemark = await GeocodingService.reverseGeocodeLocation(location: district.location) {
                try Task.checkCancellation()
                // The boundary rides along so the COVID tab can draw the district. It is the only thing that says what area these numbers
                // cover: the location above is the polygon's centroid, a computed point, not a sensor site.
                let sensor = ProcessSensor(
                    name: district.name, location: district.location, placemark: placemark,
                    customData: ["icon": "facemask", "polygons": district.polygons], measurements: measurements,
                    timestamp: Date.now)
                data.append(sensor)
            }
        }
        return data
    }

    struct District: Identifiable, Equatable {
        let id: String
        let name: String
        let location: Location
        let polygons: [[Location]]

        static func == (lhs: District, rhs: District) -> Bool { lhs.id == rhs.id }
    }

    // BKG's VG250 models Berlin as a single Kreis-level feature ("11000"), but the RKI/
    // corona-zahlen.org API reports Berlin's COVID data per Bezirk (borough), not city-wide —
    // Berlin's 12 Bezirke are not independent Gemeinden and so never appear as their own
    // features in any BKG layer. This is the only such case nationwide (verified against the
    // live RKI district list: 411 districts vs. ~401 official Kreise, with Hamburg and every
    // other city-state or kreisfreie Stadt reporting as a single district like everywhere else).
    private static let berlinWholeCityAGS = "11000"

    private func fetchDistrict(for location: Location) async throws -> District? {
        try Task.checkCancellation()
        guard let data = try await CovidService.fetchDistricts(for: location, radius: 30000) else { return nil }
        try Task.checkCancellation()
        guard let candidates = try await Self.parseDistricts(data: data), candidates.isEmpty == false else { return nil }

        let resolved: District?
        if let contained = candidates.first(where: { district in
            district.polygons.contains { isPointInPolygon(point: location, polygon: $0) }
        }) {
            resolved = contained
        }
        else {
            // Location falls outside every fetched candidate (bbox edge, fallback location) —
            // fall back to nearest polygon edge, same pattern HazardController uses.
            resolved = candidates.min { a, b in
                let distanceA = a.polygons.compactMap { PolygonProximityCalculator.nearestPointOnPolygon(from: location, to: $0)?.distance }.min() ?? .greatestFiniteMagnitude
                let distanceB = b.polygons.compactMap { PolygonProximityCalculator.nearestPointOnPolygon(from: location, to: $0)?.distance }.min() ?? .greatestFiniteMagnitude
                return distanceA < distanceB
            }
        }

        guard let resolved else { return nil }
        guard resolved.id == Self.berlinWholeCityAGS else { return resolved }

        // Resolve down to the containing Bezirk; fall back to the whole-city district
        // (which RKI doesn't recognize as a valid id) only if that somehow fails.
        return Self.resolveBerlinBezirk(for: location) ?? resolved
    }

    private static let berlinBezirkRKIIds: [String: String] = [
        "Mitte": "11001",
        "Friedrichshain-Kreuzberg": "11002",
        "Pankow": "11003",
        "Charlottenburg-Wilmersdorf": "11004",
        "Spandau": "11005",
        "Steglitz-Zehlendorf": "11006",
        "Tempelhof-Schöneberg": "11007",
        "Neukölln": "11008",
        "Treptow-Köpenick": "11009",
        "Marzahn-Hellersdorf": "11010",
        "Lichtenberg": "11011",
        "Reinickendorf": "11012",
    ]

    private static func resolveBerlinBezirk(for location: Location) -> District? {
        guard let url = Bundle.main.url(forResource: "BerlinBezirke", withExtension: "geojson"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) as? [String: Any],
              let features = json["features"] as? [[String: Any]]
        else { return nil }

        var bezirke: [District] = []
        for feature in features {
            guard let properties = feature["properties"] as? [String: Any],
                  let name = properties["name"] as? String,
                  let id = Self.berlinBezirkRKIIds[name],
                  let geometry = feature["geometry"] as? [String: Any],
                  let polygons = Self.parsePolygons(from: geometry),
                  let centroid = Self.centroid(of: polygons)
            else { continue }
            bezirke.append(District(id: id, name: "Berlin \(name)", location: centroid, polygons: polygons))
        }
        guard bezirke.isEmpty == false else { return nil }

        if let contained = bezirke.first(where: { bezirk in
            bezirk.polygons.contains { isPointInPolygon(point: location, polygon: $0) }
        }) {
            return contained
        }

        return bezirke.min { a, b in
            let distanceA = a.polygons.compactMap { PolygonProximityCalculator.nearestPointOnPolygon(from: location, to: $0)?.distance }.min() ?? .greatestFiniteMagnitude
            let distanceB = b.polygons.compactMap { PolygonProximityCalculator.nearestPointOnPolygon(from: location, to: $0)?.distance }.min() ?? .greatestFiniteMagnitude
            return distanceA < distanceB
        }
    }

    static private func parseDistricts(data: Data) async throws -> [District]? {
        guard let json = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) as? [String: Any],
              let features = json["features"] as? [[String: Any]]
        else { return nil }

        var districts: [District] = []
        for feature in features {
            guard let properties = feature["properties"] as? [String: Any],
                  let id = properties["ags"] as? String,
                  let name = properties["gen"] as? String,
                  let geometry = feature["geometry"] as? [String: Any],
                  let polygons = Self.parsePolygons(from: geometry),
                  let centroid = Self.centroid(of: polygons)
            else { continue }
            districts.append(District(id: id, name: name, location: centroid, polygons: polygons))
        }
        return districts
    }

    private static func parsePolygons(from geometry: [String: Any]) -> [[Location]]? {
        let polygons = GeoJSON.polygons(from: geometry)
        return polygons.isEmpty ? nil : polygons
    }

    // Area-weighted centroid (shoelace formula per ring, combined across a
    // MultiPolygon's rings by ring area), not a plain average of every boundary
    // vertex. A vertex average is skewed toward wherever a boundary happens to be
    // traced with more points (a winding riverbank, a jagged administrative edge),
    // and can land far from a district's actual visual center as a result.
    private static func centroid(of polygons: [[Location]]) -> Location? {
        var totalArea = 0.0
        var weightedLongitude = 0.0
        var weightedLatitude = 0.0
        for ring in polygons where ring.count >= 3 {
            var signedArea = 0.0
            var longitudeSum = 0.0
            var latitudeSum = 0.0
            for i in 0 ..< ring.count {
                let p0 = ring[i]
                let p1 = ring[(i + 1) % ring.count]
                let cross = p0.longitude * p1.latitude - p1.longitude * p0.latitude
                signedArea += cross
                longitudeSum += (p0.longitude + p1.longitude) * cross
                latitudeSum += (p0.latitude + p1.latitude) * cross
            }
            signedArea /= 2
            guard signedArea != 0 else { continue }
            let ringArea = abs(signedArea)
            totalArea += ringArea
            weightedLongitude += (longitudeSum / (6 * signedArea)) * ringArea
            weightedLatitude += (latitudeSum / (6 * signedArea)) * ringArea
        }
        guard totalArea > 0 else {
            // Degenerate geometry (every ring under 3 points or zero area) — fall
            // back to a plain vertex average rather than returning nil.
            let points = polygons.flatMap { $0 }
            guard points.isEmpty == false else { return nil }
            let latitude = points.map(\.latitude).reduce(0, +) / Double(points.count)
            let longitude = points.map(\.longitude).reduce(0, +) / Double(points.count)
            return Location(latitude: latitude, longitude: longitude)
        }
        return Location(latitude: weightedLatitude / totalArea, longitude: weightedLongitude / totalArea)
    }


    private func fetchIncidence(for district: District) async throws -> [ProcessValue<Dimension>]? {
        var incidence: [ProcessValue<Dimension>]? = nil
        try Task.checkCancellation()
        if let data = try await CovidService.fetchIncidence(id: district.id, duration: self.measurementDuration) {
            try Task.checkCancellation()
            if let measurements = try Self.parseData(data: data, district: district, tag: "weekIncidence", unit: UnitIncidence.casesPer100k) {
                incidence = measurements
                if let current = Self.nowCast(data: incidence, alpha: 0.33) {
                    incidence?.append(current)
                }
            }
        }
        return incidence
    }

    private func fetchCases(for district: District) async throws -> [ProcessValue<Dimension>]? {
        var incidence: [ProcessValue<Dimension>]? = nil
        try Task.checkCancellation()
        if let data = try await CovidService.fetchCases(id: district.id, duration: self.measurementDuration) {
            try Task.checkCancellation()
            if let measurements = try Self.parseData(data: data, district: district, tag: "cases", unit: UnitPopulation.people) {
                incidence = measurements
                if let current = Self.nowCast(data: incidence, alpha: 0.33) {
                    incidence?.append(current)
                }
            }
        }
        return incidence
    }

    private func fetchDeaths(for district: District) async throws -> [ProcessValue<Dimension>]? {
        var incidence: [ProcessValue<Dimension>]? = nil
        try Task.checkCancellation()
        if let data = try await CovidService.fetchDeaths(id: district.id, duration: self.measurementDuration) {
            try Task.checkCancellation()
            if let measurements = try Self.parseData(data: data, district: district, tag: "deaths", unit: UnitPopulation.people) {
                incidence = measurements
                if let current = Self.nowCast(data: incidence, alpha: 0.33) {
                    incidence?.append(current)
                }
            }
        }
        return incidence
    }

    private func fetchRecovered(for district: District) async throws -> [ProcessValue<Dimension>]? {
        var incidence: [ProcessValue<Dimension>]? = nil
        try Task.checkCancellation()
        if let data = try await CovidService.fetchRecovered(id: district.id, duration: self.measurementDuration) {
            try Task.checkCancellation()
            if let measurements = try Self.parseData(data: data, district: district, tag: "recovered", unit: UnitPopulation.people) {
                incidence = measurements
                if let current = Self.nowCast(data: incidence, alpha: 0.33) {
                    incidence?.append(current)
                }
            }
        }
        return incidence
    }

    static private func parseData(data: Data, district: District, tag: String, unit: Dimension) throws -> [ProcessValue<Dimension>]? {
        var incidence: [ProcessValue<Dimension>]?
        if let json = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) as? [String: Any] {
            if let data = json["data"] as? [String: Any] {
                if let district = data[district.id] as? [String: Any] {
                    if let history = district["history"] as? [[String: Any]] {
                        for entry in history {
                            if let value = entry[tag] as? Double {
                                if let dateString = entry["date"] as? String {
                                    let dateFormatter = DateFormatter()
                                    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
                                    dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
                                    if let date = dateFormatter.date(from: dateString) {
                                        let newIncidence = ProcessValue<Dimension>(
                                            value: Measurement<Dimension>(value: value, unit: unit), quality: .good,
                                            timestamp: date)
                                        if incidence == nil {
                                            incidence = [newIncidence]
                                        }
                                        else {
                                            incidence?.append(
                                                ProcessValue<Dimension>(
                                                    value: Measurement<Dimension>(value: value, unit: unit), quality: .good,
                                                    timestamp: date))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        return incidence
    }

    private static func nowCast(data: [ProcessValue<Dimension>]?, alpha: Double) -> ProcessValue<Dimension>? {
        guard let data = data, data.count > 0, alpha >= 0.0, alpha <= 1.0 else {
            return nil
        }
        let historicalData = [ProcessValue<Dimension>](data.reversed())
        if let current = historicalData.max(by: { $0.timestamp < $1.timestamp }) {
            if let timestamp = Calendar.current.date(byAdding: .day, value: 1, to: current.timestamp) {
                let value = Self.nowCast(data: historicalData[1].value, previous: historicalData[0].value, alpha: alpha)
                return ProcessValue<Dimension>(value: value, quality: .uncertain, timestamp: timestamp)
            }
        }
        return nil
    }

    private static func nowCast(
        data: Measurement<Dimension>, previous: Measurement<Dimension>, alpha: Double
    ) -> Measurement<Dimension> {
        let value = alpha * data.value + (1 - alpha) * previous.value
        return Measurement<Dimension>(value: value, unit: data.unit)
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
            let predictor = ARIMAPredictor(parameters: ARIMAParameters(p: 2, d: 1, q: 1), interval: .daily)
            do {
                try predictor.addData(dataPoints)
                let prediction = try predictor.forecast(duration: duration)
                forecastMeasurements = prediction.forecasts.map { forecast in
//                    ProcessValue<Dimension>(value: Measurement(value: forecast.value, unit: unit), quality: .uncertain, timestamp: forecast.timestamp)
                    ProcessValue<Dimension>(value: Measurement(value: 0.0, unit: unit), quality: .unknown, timestamp: forecast.timestamp)
                }
            }
            catch {
                trace.error("Forecasting error: %@", error.localizedDescription)
            }
        }
        return forecastMeasurements
    }
}
