import Foundation

/// Coordinates the shared Overpass quota without blocking unrelated HTTP requests.
actor OverpassRequestScheduler {
    private struct Waiter {
        let id: UUID
        let priority: TaskPriority
        let continuation: CheckedContinuation<Void, Error>
    }

    private let transport: NetworkManager.Transport
    private let sleep: NetworkManager.Sleep
    private let now: @Sendable () -> Date
    var queuedCount: Int { return self.waiters.count }

    private var active = false
    private var waiters: [Waiter] = []
    private var unavailableUntil: [String: Date] = [:]
    private var cooldownUntil: Date?
    private static let hosts = ["overpass-api.de", "overpass.private.coffee"]

    init(transport: @escaping NetworkManager.Transport, sleep: @escaping NetworkManager.Sleep, now: @escaping @Sendable () -> Date = Date.init) {
        self.transport = transport
        self.sleep = sleep
        self.now = now
    }

    func perform(_ request: URLRequest, priority: TaskPriority) async -> Result<Data, NetworkError> {
        do {
            // Give district and waterway discovery a head start at startup. No
            // permit is held here, and queued foreground work always goes first.
            if priority == .background { try await self.sleep(.seconds(2)) }
            try await self.acquire(priority: priority)
        }
        catch { return .failure(.taskCancelled) }
        defer { self.release() }
        var lastError = NetworkError.networkUnavailable
        for host in Self.hosts {
            if let until = self.unavailableUntil[host], until > self.now() { continue }
            guard let url = request.url, var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                return .failure(.invalidURL)
            }
            components.host = host
            guard let endpoint = components.url else { return .failure(.invalidURL) }
            var attempt = request
            attempt.url = endpoint
            attempt.timeoutInterval = 35
            for retry in 0 ..< 2 {
                do {
                    try Task.checkCancellation()
                    if let until = self.cooldownUntil {
                        let remaining = until.timeIntervalSince(self.now())
                        if remaining > 0 { try await self.sleep(.seconds(remaining)) }
                    }
                    try Task.checkCancellation()
                    let (data, response) = try await self.transport(attempt)
                    try Task.checkCancellation()
                    guard let response = response as? HTTPURLResponse else { return .failure(.invalidResponse) }
                    if (200 ... 299).contains(response.statusCode) {
                        if Self.hasRuntimeError(data) == false { return .success(data) }
                        lastError = .invalidResponse
                        self.unavailableUntil[host] = self.now().addingTimeInterval(60)
                        break
                    }
                    lastError = .serverError(statusCode: response.statusCode)
                    if response.statusCode == 429 {
                        let delay = Self.retryDelay(response: response, now: self.now())
                        self.cooldownUntil = self.now().addingTimeInterval(delay)
                        if retry == 0 { continue }
                        // Never rotate endpoints to evade a quota refusal.
                        return .failure(lastError)
                    }
                    if response.statusCode >= 500 {
                        self.unavailableUntil[host] = self.now().addingTimeInterval(60)
                        break
                    }
                    return .failure(lastError)
                }
                catch {
                    if Task.isCancelled == true || error is CancellationError || (error as? URLError)?.code == .cancelled {
                        return .failure(.taskCancelled)
                    }
                    lastError = (error as? URLError)?.code == .timedOut ? .timeout : .networkUnavailable
                    self.unavailableUntil[host] = self.now().addingTimeInterval(300)
                    break
                }
            }
        }
        return .failure(lastError)
    }

    private func acquire(priority: TaskPriority) async throws {
        let id = UUID()
        try await withTaskCancellationHandler {
            try Task.checkCancellation()
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                if Task.isCancelled == true {
                    continuation.resume(throwing: CancellationError())
                }
                else if self.active == false {
                    self.active = true
                    continuation.resume()
                }
                else {
                    self.waiters.append(Waiter(id: id, priority: priority, continuation: continuation))
                }
            }
        } onCancel: {
            Task { await self.cancel(id) }
        }
    }

    private func cancel(_ id: UUID) {
        guard let index = self.waiters.firstIndex(where: { $0.id == id }) else { return }
        self.waiters.remove(at: index).continuation.resume(throwing: CancellationError())
    }

    private func release() {
        guard let priority = self.waiters.map(\.priority.rawValue).max(),
            let index = self.waiters.firstIndex(where: { $0.priority.rawValue == priority })
        else {
            self.active = false
            return
        }
        self.waiters.remove(at: index).continuation.resume()
    }

    static func retryDelay(response: HTTPURLResponse, now: Date) -> TimeInterval {
        guard let value = response.value(forHTTPHeaderField: "Retry-After") else { return 30 }
        if let seconds = TimeInterval(value), seconds.isFinite == true { return max(30, seconds) }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        guard let date = formatter.date(from: value) else { return 30 }
        return max(30, date.timeIntervalSince(now))
    }

    private static func hasRuntimeError(_ data: Data) -> Bool {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let remark = json["remark"] as? String else {
            return false
        }
        return remark.localizedCaseInsensitiveContains("runtime error") || remark.localizedCaseInsensitiveContains("out of memory")
    }
}
