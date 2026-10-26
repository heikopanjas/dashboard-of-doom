import CoreLocation
import DoomKitLocation
import Foundation
import Observation

@MainActor @Observable final class PointOfInterestPresenter {
    typealias Fetch = @Sendable (PointOfInterestCategory, Location) async throws -> [PointOfInterest]
    private struct Cache {
        let center: Location
        let date: Date
        let points: [PointOfInterest]
    }
    private struct Attempt {
        let center: Location
        let date: Date
    }
    private struct Response: Sendable {
        let category: PointOfInterestCategory
        let result: Result<[PointOfInterest], Error>
    }

    /// What the map shows: filtered by the master switch and the category switches.
    private(set) var points: [PointOfInterest] = []
    /// Every loaded point near the user, regardless of the switches. Only populated
    /// beyond `points` when the presenter fetches while hidden.
    private(set) var allPoints: [PointOfInterest] = []
    private(set) var isEnabled: Bool
    private(set) var categories: Set<PointOfInterestCategory>

    /// True when the map will draw pins: the master switch is on and at least one
    /// category is selected. Read from the switches, not from `points`, so it holds
    /// steady while a fetch is in flight instead of flickering with the loaded data.
    var showsAnyPlaces: Bool { return self.isEnabled == true && self.categories.isEmpty == false }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let fetch: Fetch
    @ObservationIgnored private let fetchesWhenHidden: Bool
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let sleep: @Sendable () async throws -> Void
    @ObservationIgnored private var cache: [PointOfInterestCategory: Cache] = [:]
    @ObservationIgnored private var attempts: [PointOfInterestCategory: Attempt] = [:]
    @ObservationIgnored private var location: Location?
    @ObservationIgnored private var batchCenter: Location?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var running = false
    @ObservationIgnored private var locationTask: Task<Void, Never>?
    @ObservationIgnored private var timerTask: Task<Void, Never>?
    @ObservationIgnored private var refreshTask: Task<Void, Never>?

    /// `fetchesWhenHidden` keeps every category loading while the switches are off, so a
    /// consumer other than the map (the iOS nearest places row) always has data.
    init(
        defaults: UserDefaults = .standard, fetch: @escaping Fetch,
        now: @escaping () -> Date = Date.init,
        sleep: @escaping @Sendable () async throws -> Void = { try await Task.sleep(for: .seconds(60)) },
        fetchesWhenHidden: Bool = false
    ) {
        self.defaults = defaults
        self.fetch = fetch
        self.fetchesWhenHidden = fetchesWhenHidden
        self.now = now
        self.sleep = sleep
        self.isEnabled = defaults.object(forKey: "showPlaces") as? Bool ?? true
        self.categories = Set(PointOfInterestCategory.allCases.filter { defaults.object(forKey: $0.preferenceKey) as? Bool ?? true })
    }

    isolated deinit {
        self.locationTask?.cancel()
        self.timerTask?.cancel()
        self.refreshTask?.cancel()
    }

    func start(updates: AsyncStream<LocationState>) {
        guard self.running == false else { return }
        self.running = true
        self.locationTask = Task { [weak self] in
            for await state in updates {
                guard Task.isCancelled == false else { return }
                self?.updateLocation(state.location)
            }
        }
        let sleep = self.sleep
        self.timerTask = Task { [weak self] in
            while Task.isCancelled == false {
                do { try await sleep() }
                catch { return }
                guard Task.isCancelled == false else { return }
                self?.refreshIfNeeded()
            }
        }
    }

    func stop() {
        self.running = false
        self.locationTask?.cancel()
        self.locationTask = nil
        self.timerTask?.cancel()
        self.timerTask = nil
        self.cancelRefresh()
    }

    func setEnabled(_ enabled: Bool) {
        self.isEnabled = enabled
        self.defaults.set(enabled, forKey: "showPlaces")
        self.settingsChanged()
    }

    func setCategory(_ category: PointOfInterestCategory, enabled: Bool) {
        if enabled == true {
            self.categories.insert(category)
        }
        else {
            self.categories.remove(category)
        }
        self.defaults.set(enabled, forKey: category.preferenceKey)
        self.settingsChanged()
    }

    private func settingsChanged() {
        self.cancelRefresh()
        self.publish()
        self.refreshIfNeeded()
    }

    func updateLocation(_ location: Location) {
        self.location = location
        if let center = self.batchCenter, Self.distance(center, location) >= 1000 {
            self.cancelRefresh()
        }
        self.publish()
        self.refreshIfNeeded()
    }

    private func cancelRefresh() {
        self.generation += 1
        self.refreshTask?.cancel()
        self.batchCenter = nil
        // Keep the task handle until its replacement awaits completion. Even a
        // cancellation-insensitive transport cannot overlap two fetch generations.
    }

    func refreshIfNeeded() {
        guard self.running == true, self.isEnabled == true || self.fetchesWhenHidden == true, let location = self.location,
            self.batchCenter == nil
        else { return }
        let date = self.now()
        let categories = PointOfInterestCategory.allCases.filter { category in
            guard self.fetchesWhenHidden == true || self.categories.contains(category) == true else { return false }
            if let cached = self.cache[category], Self.distance(cached.center, location) < 1000, date.timeIntervalSince(cached.date) < 3600 {
                return false
            }
            if let attempt = self.attempts[category], Self.distance(attempt.center, location) < 1000, date.timeIntervalSince(attempt.date) < 300 {
                return false
            }
            return true
        }
        guard categories.isEmpty == false else { return }
        let previous = self.refreshTask
        let generation = self.generation
        let fetch = self.fetch
        self.batchCenter = location
        self.refreshTask = Task { [weak self] in
            await previous?.value
            guard Task.isCancelled == false else { return }
            await withTaskGroup(of: Response.self) { group in
                var iterator = categories.makeIterator()
                func submit(_ category: PointOfInterestCategory) {
                    group.addTask {
                        do {
                            try Task.checkCancellation()
                            return Response(category: category, result: .success(try await fetch(category, location)))
                        }
                        catch { return Response(category: category, result: .failure(error)) }
                    }
                }
                for _ in 0 ..< 2 { if let category = iterator.next() { submit(category) } }
                for await response in group {
                    self?.receive(response, center: location, generation: generation)
                    if Task.isCancelled == false, let category = iterator.next() { submit(category) }
                }
            }
            guard Task.isCancelled == false, let self, self.generation == generation, self.running == true else { return }
            self.batchCenter = nil
        }
    }

    private func receive(_ response: Response, center: Location, generation: Int) {
        guard Task.isCancelled == false, self.generation == generation, self.running == true else { return }
        let completed = self.now()
        self.attempts[response.category] = Attempt(center: center, date: completed)
        if case .success(let points) = response.result {
            self.cache[response.category] = Cache(center: center, date: completed, points: points)
            self.publish()
        }
    }

    private func publish() {
        guard let location = self.location else {
            if self.points.isEmpty == false { self.points = [] }
            if self.allPoints.isEmpty == false { self.allPoints = [] }
            return
        }
        let all = PointOfInterestCategory.allCases.flatMap { category -> [PointOfInterest] in
            guard let cached = self.cache[category], Self.distance(cached.center, location) < 1000 else { return [] }
            return cached.points
        }
        let points = self.isEnabled == true ? all.filter { self.categories.contains($0.category) } : []
        if all != self.allPoints { self.allPoints = all }
        if points != self.points { self.points = points }
    }

    static func distance(_ first: Location, _ second: Location) -> Double {
        return CLLocation(latitude: first.latitude, longitude: first.longitude)
            .distance(from: CLLocation(latitude: second.latitude, longitude: second.longitude))
    }
}
