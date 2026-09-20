import DoomKitLocation
import DoomKitProcess
import DoomKitServices
import DoomKitTools
import Foundation

/// Fetches the NINA warnings near a location: list feeds first, then the small
/// geojson per alert to decide relevance, and only then the CAP details for the
/// alerts that are inside or close enough.
struct HazardController {
    enum Failure: Error {
        case listUnavailable(HazardFeed)
        case detailUnavailable(String)
    }

    /// DWD polygons are county-sized, so 50 km reaches the neighbouring ring of counties.
    static let weatherRadius: Double = 50_000
    /// Civil protection alerts are village-sized and not actionable further out.
    static let civilRadius: Double = 25_000
    /// The feeds only list active alerts; this guards against a stale feed, nothing more.
    static let staleAfter: TimeInterval = 30 * 24 * 3600
    static let regionConcurrency = 4
    static let detailConcurrency = 2

    struct Candidate: Sendable, Equatable {
        let id: String
        let feed: HazardFeed
        let expires: Date?
    }

    struct Placed: Sendable {
        let candidate: Candidate
        let location: Location
        let distance: Double
    }

    /// Everything the CAP detail carries that the card shows.
    struct Details: Sendable, Equatable {
        let id: String
        let event: String?
        let headline: String
        let description: String
        let instruction: String?
        let severity: Hazard.Severity
        let sent: Date
        let expires: Date?
        let areaDescription: String?
    }

    func fetchHazards(location: Location, now: Date = .now) async throws -> [Hazard] {
        try Task.checkCancellation()
        let candidates = try await Self.candidates(now: now)
        try Task.checkCancellation()
        let placed = try await Self.locate(candidates, near: location)
        try Task.checkCancellation()
        let hazards = try await Self.detail(placed, now: now)
        try Task.checkCancellation()
        return hazards.sorted { first, second in
            if first.isInside != second.isInside { return first.isInside }
            if first.severity != second.severity { return first.severity > second.severity }
            return first.sent > second.sent
        }
    }

    // MARK: - Stage 1: list feeds

    /// All four feeds concurrently. One failing feed fails the refresh, because a
    /// partial list would read as an all-clear.
    private static func candidates(now: Date) async throws -> [Candidate] {
        return try await withThrowingTaskGroup(of: [Candidate].self) { group in
            for feed in HazardFeed.allCases {
                group.addTask {
                    try Task.checkCancellation()
                    guard let data = try await HazardService.fetchHazardList(feed: feed) else {
                        try Task.checkCancellation()
                        throw Failure.listUnavailable(feed)
                    }
                    return try Self.parseList(data, feed: feed, now: now)
                }
            }
            var all: [Candidate] = []
            for try await part in group { all.append(contentsOf: part) }
            return all
        }
    }

    static func parseList(_ data: Data, feed: HazardFeed, now: Date) throws -> [Candidate] {
        guard let items = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) as? [[String: Any]] else {
            return []
        }
        return items.compactMap { item in
            guard let id = item["id"] as? String else { return nil }
            if let type = item["type"] as? String, type.caseInsensitiveCompare("Cancel") == .orderedSame { return nil }
            let expires = Self.date(item["expiresDate"])
            if let expires, expires < now { return nil }
            return Candidate(id: id, feed: feed, expires: expires)
        }
    }

    // MARK: - Stage 2: geometry

    /// Fetches each alert's region with at most `regionConcurrency` in flight and
    /// keeps the ones inside or within the feed's radius. A missing region drops
    /// that alert only.
    private static func locate(_ candidates: [Candidate], near location: Location) async throws -> [Placed] {
        return try await withThrowingTaskGroup(of: Placed?.self) { group in
            var iterator = candidates.makeIterator()
            func submit(_ candidate: Candidate) {
                group.addTask {
                    try Task.checkCancellation()
                    guard let data = try await HazardService.fetchHazardRegion(for: candidate.id) else {
                        try Task.checkCancellation()
                        return nil
                    }
                    guard let json = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) as? [String: Any]
                    else { return nil }
                    return Self.place(candidate, polygons: GeoJSON.polygons(fromFeatureCollection: json), near: location)
                }
            }
            for _ in 0..<Self.regionConcurrency {
                if let next = iterator.next() { submit(next) }
            }
            var placed: [Placed] = []
            for try await result in group {
                if let result { placed.append(result) }
                if Task.isCancelled == false, let next = iterator.next() { submit(next) }
            }
            return placed
        }
    }

    static func place(_ candidate: Candidate, polygons: [[Location]], near location: Location) -> Placed? {
        if polygons.contains(where: { isPointInPolygon(point: location, polygon: $0) }) {
            return Placed(candidate: candidate, location: location, distance: 0)
        }
        let nearest = polygons
            .compactMap { PolygonProximityCalculator.nearestPointOnPolygon(from: location, to: $0) }
            .min { $0.distance < $1.distance }
        guard let nearest, nearest.distance <= Self.radius(for: candidate.feed) else { return nil }
        return Placed(candidate: candidate, location: nearest.point, distance: nearest.distance)
    }

    static func radius(for feed: HazardFeed) -> Double {
        return feed == .dwd ? Self.weatherRadius : Self.civilRadius
    }

    // MARK: - Stage 3: details

    /// CAP details for the survivors, at most `detailConcurrency` in flight. A
    /// missing detail fails the refresh; reverse geocoding runs only for alerts
    /// without an area description.
    private static func detail(_ placed: [Placed], now: Date) async throws -> [Hazard] {
        return try await withThrowingTaskGroup(of: Hazard?.self) { group in
            var iterator = placed.makeIterator()
            func submit(_ entry: Placed) {
                group.addTask {
                    try Task.checkCancellation()
                    guard let data = try await HazardService.fetchHazardDetails(for: entry.candidate.id) else {
                        try Task.checkCancellation()
                        throw Failure.detailUnavailable(entry.candidate.id)
                    }
                    guard let details = try Self.parseDetails(data, now: now) else { return nil }
                    var placemark: String? = nil
                    if details.areaDescription == nil {
                        try Task.checkCancellation()
                        placemark = await GeocodingService.reverseGeocodeLocation(location: entry.location, fullAddress: false)
                    }
                    return Hazard(
                        id: details.id, feed: entry.candidate.feed, event: details.event, headline: details.headline,
                        description: details.description, instruction: details.instruction, severity: details.severity,
                        sent: details.sent, expires: details.expires ?? entry.candidate.expires,
                        areaDescription: details.areaDescription, location: entry.location, distance: entry.distance,
                        placemark: placemark)
                }
            }
            for _ in 0..<Self.detailConcurrency {
                if let next = iterator.next() { submit(next) }
            }
            var hazards: [Hazard] = []
            for try await result in group {
                if let result { hazards.append(result) }
                if Task.isCancelled == false, let next = iterator.next() { submit(next) }
            }
            return hazards
        }
    }

    static func parseDetails(_ data: Data, now: Date) throws -> Details? {
        guard let json = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) as? [String: Any],
            let id = json["identifier"] as? String,
            let sent = Self.date(json["sent"]),
            let info = Self.germanInfo(json["info"]),
            let headline = info["headline"] as? String
        else { return nil }
        if sent < now.addingTimeInterval(-Self.staleAfter) { return nil }
        let expires = Self.date(info["expires"])
        if let expires, expires < now { return nil }
        let areas = (info["area"] as? [[String: Any]] ?? []).compactMap { $0["areaDesc"] as? String }.filter { $0.isEmpty == false }
        return Details(
            id: id, event: Self.text(info["event"]), headline: headline,
            description: Self.sanitize(info["description"] as? String) ?? "",
            instruction: Self.sanitize(info["instruction"] as? String),
            severity: Hazard.Severity(cap: info["severity"] as? String), sent: sent, expires: expires,
            areaDescription: areas.isEmpty ? nil : areas.joined(separator: ", "))
    }

    /// The German entry, skipping Leichte Sprache; the first entry when there is none.
    static func germanInfo(_ value: Any?) -> [String: Any]? {
        guard let infos = value as? [[String: Any]] else { return nil }
        let german = infos.first { info in
            guard let language = info["language"] as? String else { return false }
            return language.hasPrefix("de") && language != "de-LS"
        }
        return german ?? infos.first
    }

    // MARK: - Helpers

    private static func text(_ value: Any?) -> String? {
        guard let string = value as? String, string.isEmpty == false else { return nil }
        return string
    }

    static func sanitize(_ description: String?) -> String? {
        guard let description, description.isEmpty == false else { return nil }
        return description.replacingOccurrences(of: "<br/>", with: "\n").replacingOccurrences(of: "<br />", with: "\n")
    }

    /// A formatter per call: the parsers run inside task group children, and
    /// the old code proved this formatter accepts NINA's `+02:00` offsets.
    static func date(_ value: Any?) -> Date? {
        guard let string = value as? String else { return nil }
        return ISO8601DateFormatter().date(from: string)
    }
}
