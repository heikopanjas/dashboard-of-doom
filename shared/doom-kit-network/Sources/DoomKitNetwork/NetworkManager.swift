import Foundation

public actor NetworkManager {
    public typealias Transport = @Sendable (URLRequest) async throws -> (Data, URLResponse)
    public typealias Sleep = @Sendable (Duration) async throws -> Void
    public static let shared = NetworkManager()

    public private(set) var state = NetworkState()
    public var isConnected: Bool { return self.state.isConnected }
    public var connectionType: ConnectionType { return self.state.connectionType }

    private let overpass: OverpassRequestScheduler
    private let transport: Transport
    private let makeMonitor: @Sendable () -> any NetworkMonitoring
    private let sleep: Sleep
    private let probeURL: URL?
    private var monitor: (any NetworkMonitoring)?
    private var generation = UUID()
    private var observers: [UUID: AsyncStream<NetworkState>.Continuation] = [:]

    public init(
        transport: Transport? = nil,
        makeMonitor: (@Sendable () -> any NetworkMonitoring)? = nil,
        sleep: Sleep? = nil,
        probeURL: URL? = URL(string: "https://www.apple.com/library/test/success.html")
    ) {
        self.transport = transport ?? { request in return try await URLSession.shared.data(for: request) }
        self.makeMonitor = makeMonitor ?? { return PathMonitoring() }
        self.sleep = sleep ?? { duration in try await Task.sleep(for: duration) }
        self.probeURL = probeURL
        self.overpass = OverpassRequestScheduler(transport: self.transport, sleep: self.sleep)
    }

    public func updates() -> AsyncStream<NetworkState> {
        return self.makeObservation().stream
    }

    var observerCount: Int { return self.observers.count }

    private func makeObservation() -> (id: UUID, stream: AsyncStream<NetworkState>) {
        let id = UUID()
        let (stream, continuation) = AsyncStream.makeStream(of: NetworkState.self, bufferingPolicy: .bufferingNewest(1))
        self.observers[id] = continuation
        continuation.yield(self.state)
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeObserver(id) }
        }
        return (id, stream)
    }

    private func removeObserver(_ id: UUID) {
        self.observers.removeValue(forKey: id)
    }

    public func startMonitoring() async {
        guard Task.isCancelled == false, self.state.isMonitoring == false else { return }
        let generation = UUID()
        self.generation = generation
        let monitor = self.makeMonitor()
        self.monitor = monitor
        self.state = NetworkState(isMonitoring: true)
        self.broadcast()
        await monitor.start { [weak self] connected, type in
            Task { await self?.receive(connected: connected, type: type, generation: generation) }
        }
        // A concurrent stop may have completed while the adapter started.
        if self.generation != generation { await monitor.stop() }
    }

    public func stopMonitoring() async {
        self.generation = UUID()
        let monitor = self.monitor
        self.monitor = nil
        self.state = NetworkState()
        self.broadcast()
        for continuation in self.observers.values { continuation.finish() }
        self.observers.removeAll()
        await monitor?.stop()
    }

    private func receive(connected: Bool, type: ConnectionType, generation: UUID) {
        guard self.generation == generation, self.state.isMonitoring == true else { return }
        self.state = NetworkState(isInitialized: true, isMonitoring: true, isConnected: connected, connectionType: type)
        self.broadcast()
    }

    private func broadcast() {
        for continuation in self.observers.values { continuation.yield(self.state) }
    }

    /// Waits on this manager's observation stream. Cancellation and timeout
    /// both release the observer and cancel its owned timeout task.
    public func waitForConnection(timeout: Duration = .seconds(30)) async throws -> Void {
        try Task.checkCancellation()
        if self.state.isConnected == true { return }
        let observation = self.makeObservation()
        defer { self.observers.removeValue(forKey: observation.id)?.finish() }
        try await Self.wait(stream: observation.stream, timeout: timeout, sleep: self.sleep)
    }

    private nonisolated static func wait(stream: AsyncStream<NetworkState>, timeout: Duration, sleep: @escaping Sleep) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                for await state in stream {
                    try Task.checkCancellation()
                    if state.isConnected == true { return }
                    if state.isMonitoring == false { throw NetworkError.networkUnavailable }
                }
                try Task.checkCancellation()
                throw NetworkError.networkUnavailable
            }
            group.addTask {
                try await sleep(timeout)
                throw NetworkError.timeout
            }
            defer { group.cancelAll() }
            _ = try await group.next()
        }
    }

    private func ready() async throws -> Void {
        try Task.checkCancellation()
        await self.startMonitoring()
        if self.state.isConnected == true { return }
        if let probeURL = self.probeURL {
            var probe = URLRequest(url: probeURL)
            probe.httpMethod = "HEAD"
            probe.timeoutInterval = 10
            do {
                let (_, response) = try await self.transport(probe)
                try Task.checkCancellation()
                if let response = response as? HTTPURLResponse, (200 ... 299).contains(response.statusCode) {
                    return
                }
            }
            catch {
                if Task.isCancelled == true || (error as? URLError)?.code == .cancelled {
                    throw CancellationError()
                }
            }
        }
        try await self.waitForConnection(timeout: .seconds(15))
    }

    public func performDataRequest(
        urlString: String, method: String = "GET", body: Data? = nil,
        headers: [String: String]? = nil, priority: TaskPriority = .userInitiated
    ) async -> Result<Data, NetworkError> {
        guard let url = URL(string: urlString), let scheme = url.scheme,
            ["http", "https"].contains(scheme), url.host != nil
        else { return .failure(.invalidURL) }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        for (key, value) in headers ?? [:] { request.setValue(value, forHTTPHeaderField: key) }
        if url.host == "overpass-api.de", url.path == "/api/interpreter" {
            do { try await self.ready() }
            catch is CancellationError { return .failure(.taskCancelled) }
            catch let error as NetworkError { return .failure(error) }
            catch { return .failure(.networkUnavailable) }
            return await self.overpass.perform(request, priority: priority)
        }
        var lastError: NetworkError = .invalidResponse
        for attempt in 1 ... 5 {
            if Task.isCancelled == true { return .failure(.taskCancelled) }
            do { try await self.ready() }
            catch is CancellationError { return .failure(.taskCancelled) }
            catch let error as NetworkError { return .failure(error) }
            catch { return .failure(.networkUnavailable) }
            do {
                let (data, response) = try await self.transport(request)
                try Task.checkCancellation()
                guard let response = response as? HTTPURLResponse else { return .failure(.invalidResponse) }
                if (200 ... 299).contains(response.statusCode) { return .success(data) }
                lastError = .serverError(statusCode: response.statusCode)
            }
            catch is CancellationError { return .failure(.taskCancelled) }
            catch let error as URLError {
                switch error.code {
                    case .cancelled: return .failure(.taskCancelled)
                    case .notConnectedToInternet, .networkConnectionLost: lastError = .networkUnavailable
                    case .timedOut: lastError = .timeout
                    default: lastError = .invalidResponse
                }
            }
            catch { return .failure(.invalidResponse) }
            if attempt < 5 {
                do { try await self.sleep(.seconds(min(pow(2, Double(attempt)), 60))) }
                catch { return .failure(.taskCancelled) }
            }
        }
        return .failure(lastError)
    }

    public func performRequest<T: Decodable & Sendable>(
        urlString: String, method: String = "GET", body: Data? = nil,
        headers: [String: String]? = nil, decoder: JSONDecoder = JSONDecoder()
    ) async -> Result<T, NetworkError> {
        switch await self.performDataRequest(urlString: urlString, method: method, body: body, headers: headers) {
            case .success(let data):
                if Task.isCancelled == true { return .failure(.taskCancelled) }
                do { return .success(try decoder.decode(T.self, from: data)) }
                catch { return .failure(.decodingError(error: error)) }
            case .failure(let error): return .failure(error)
        }
    }

    deinit {
        for continuation in self.observers.values { continuation.finish() }
        let monitor = self.monitor
        Task { await monitor?.stop() }
    }
}
