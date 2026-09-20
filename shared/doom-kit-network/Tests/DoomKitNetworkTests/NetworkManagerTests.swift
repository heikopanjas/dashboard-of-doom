import Foundation
import Testing

@testable import DoomKitNetwork

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct NetworkManagerTests {
    actor Monitor: NetworkMonitoring {
        var callbacks: [@Sendable (Bool, ConnectionType) -> Void] = []
        let connected: Bool
        var stops = 0
        init(connected: Bool = true) { self.connected = connected }
        func start(_ receive: @escaping @Sendable (Bool, ConnectionType) -> Void) {
            self.callbacks.append(receive)
            receive(self.connected, .wifi)
        }
        func stop() { self.stops += 1 }
        func send(_ connected: Bool, index: Int = 0) { self.callbacks[index](connected, .ethernet) }
    }

    actor Requests {
        var requests: [URLRequest] = []
        var delays: [Duration] = []
        let status: Int
        let data: Data
        let error: URLError?
        init(status: Int = 200, data: Data = Data("42".utf8), error: URLError? = nil) {
            self.status = status
            self.data = data
            self.error = error
        }
        func call(_ request: URLRequest) throws -> (Data, URLResponse) {
            self.requests.append(request)
            if let error = self.error { throw error }
            let url = try #require(request.url)
            let response = try #require(HTTPURLResponse(url: url, statusCode: self.status, httpVersion: nil, headerFields: nil))
            return (self.data, response)
        }
        func sleep(_ duration: Duration) { self.delays.append(duration) }
    }

    private func ready(_ manager: NetworkManager) async throws {
        await manager.startMonitoring()
        try await manager.waitForConnection(timeout: .seconds(2))
    }

    @Test func requestsAndDecoding() async throws {
        let monitor = Monitor()
        let requests = Requests()
        let manager = NetworkManager(transport: { try await requests.call($0) }, makeMonitor: { monitor }, probeURL: nil)
        try await self.ready(manager)
        let result: Result<Int, NetworkError> = await manager.performRequest(
            urlString: "https://example.test/data", method: "POST", body: Data("body".utf8), headers: ["X-Test": "value"])
        #expect(try result.get() == 42)
        let request = try #require(await requests.requests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.httpBody == Data("body".utf8))
        #expect(request.value(forHTTPHeaderField: "X-Test") == "value")
        await manager.stopMonitoring()
    }

    @Test(arguments: [400, 503])
    func httpRetryLimits(status: Int) async throws {
        let monitor = Monitor()
        let requests = Requests(status: status)
        let manager = NetworkManager(
            transport: { try await requests.call($0) }, makeMonitor: { monitor },
            sleep: { await requests.sleep($0) }, probeURL: nil)
        // Observe initialization without racing an immediate fake timeout.
        await manager.startMonitoring()
        for await state in await manager.updates() where state.isInitialized == true { break }
        let outcome1 = await manager.performDataRequest(urlString: "https://example.test")
        if case .failure(.serverError(let code)) = outcome1 {
            #expect(code == status)
        }
        else {
            Issue.record("Expected HTTP error")
        }
        #expect(await requests.requests.count == 5)
        #expect(await requests.delays == [.seconds(2), .seconds(4), .seconds(8), .seconds(16)])
        await manager.stopMonitoring()
    }

    @Test func transportTimeoutAndCancellation() async throws {
        let monitor = Monitor()
        let requests = Requests(error: URLError(.timedOut))
        let manager = NetworkManager(
            transport: { try await requests.call($0) }, makeMonitor: { monitor },
            sleep: { await requests.sleep($0) }, probeURL: nil)
        await manager.startMonitoring()
        for await state in await manager.updates() where state.isInitialized == true { break }
        let outcome2 = await manager.performDataRequest(urlString: "https://example.test")
        if case .failure(.timeout) = outcome2 {
        }
        else {
            Issue.record("Expected timeout")
        }
        #expect(await requests.requests.count == 5)
        let task = Task { await manager.performDataRequest(urlString: "https://example.test") }
        task.cancel()
        let outcome3 = await task.value
        if case .failure(.taskCancelled) = outcome3 {
        }
        else {
            Issue.record("Expected cancellation")
        }
        await manager.stopMonitoring()
    }

    @Test func offlineTimeoutAndCancelledWait() async {
        let monitor = Monitor(connected: false)
        let manager = NetworkManager(makeMonitor: { monitor }, probeURL: nil)
        await manager.startMonitoring()
        do {
            try await manager.waitForConnection(timeout: .milliseconds(1))
            Issue.record("Expected timeout")
        }
        catch NetworkError.timeout {}
        catch { Issue.record("Unexpected error: \(error)") }
        let task = Task { try await manager.waitForConnection(timeout: .seconds(100)) }
        task.cancel()
        do {
            try await task.value
            Issue.record("Expected cancellation")
        }
        catch is CancellationError {}
        catch { Issue.record("Unexpected error: \(error)") }
        await manager.stopMonitoring()
    }

    @Test func observerReplayAndShutdown() async throws {
        let monitor = Monitor()
        let manager = NetworkManager(makeMonitor: { monitor }, probeURL: nil)
        try await self.ready(manager)
        let firstStream = await manager.updates()
        let secondStream = await manager.updates()
        var first = firstStream.makeAsyncIterator()
        var second = secondStream.makeAsyncIterator()
        let replay = await first.next()
        #expect(replay?.isConnected == true)
        await manager.stopMonitoring()
        let stopped = await second.next()
        #expect(stopped?.isMonitoring == false)
        let end = await second.next()
        #expect(end == nil)
    }

    @Test func restartAndStaleCallbacks() async throws {
        let monitor = Monitor()
        let manager = NetworkManager(makeMonitor: { monitor }, probeURL: nil)
        try await self.ready(manager)
        await manager.stopMonitoring()
        try await self.ready(manager)
        await monitor.send(false, index: 0)
        await monitor.send(true, index: 1)
        let stream = await manager.updates()
        for await state in stream where state.connectionType == .ethernet {
            #expect(state.isConnected == true)
            break
        }
        await manager.stopMonitoring()
        #expect(await monitor.stops == 2)
    }

    @Test func independentCancellation() async throws {
        let monitor = Monitor()
        let manager = NetworkManager(makeMonitor: { monitor }, probeURL: nil)
        try await self.ready(manager)
        let stream = await manager.updates()
        let cancelled = Task { for await _ in stream {} }
        cancelled.cancel()
        await cancelled.value
        #expect(await manager.state.isConnected == true)
        let remaining = await manager.updates()
        var iterator = remaining.makeAsyncIterator()
        let state = await iterator.next()
        #expect(state?.isConnected == true)
        await manager.stopMonitoring()
    }

    @Test func invalidURLAndDecodingFailure() async throws {
        let monitor = Monitor()
        let requests = Requests(data: Data("bad json".utf8))
        let manager = NetworkManager(transport: { try await requests.call($0) }, makeMonitor: { monitor }, probeURL: nil)
        let outcome5 = await manager.performDataRequest(urlString: "relative")
        if case .failure(.invalidURL) = outcome5 {
        }
        else {
            Issue.record("Expected invalid URL")
        }
        try await self.ready(manager)
        let result: Result<Int, NetworkError> = await manager.performRequest(urlString: "https://example.test")
        if case .failure(.decodingError) = result {
        }
        else {
            Issue.record("Expected decoding failure")
        }
        #expect(await requests.requests.count == 1)
        await manager.stopMonitoring()
    }
    @Test func offlineRecoveryAndProbeConfiguration() async throws {
        let monitor = Monitor(connected: false)
        let requests = Requests()
        let manager = NetworkManager(
            transport: { try await requests.call($0) },
            makeMonitor: { monitor })
        let result = await manager.performDataRequest(urlString: "https://example.test")
        #expect(try result.get() == Data("42".utf8))
        let calls = await requests.requests
        #expect(calls.count == 2)
        #expect(calls.first?.httpMethod == "HEAD")
        #expect(calls.first?.timeoutInterval == 10)
        #expect(calls.first?.url?.host == "www.apple.com")
        await manager.stopMonitoring()

        let offline = Monitor(connected: false)
        let recovered = NetworkManager(
            transport: { try await requests.call($0) },
            makeMonitor: { offline }, probeURL: nil)
        await recovered.startMonitoring()
        let request = Task { await recovered.performDataRequest(urlString: "https://example.test") }
        await offline.send(true)
        let response = await request.value
        #expect(try response.get() == Data("42".utf8))
        await recovered.stopMonitoring()
    }

    @Test func cancellationDuringBackoff() async throws {
        let monitor = Monitor()
        let requests = Requests(status: 500)
        let sleeping = AsyncStream.makeStream(of: Void.self)
        let manager = NetworkManager(
            transport: { try await requests.call($0) }, makeMonitor: { monitor },
            sleep: { _ in
                sleeping.continuation.yield(())
                try await Task.sleep(for: .seconds(100))
            }, probeURL: nil)
        // Use state replay so readiness does not consume the injected backoff clock.
        await manager.startMonitoring()
        for await state in await manager.updates() where state.isConnected == true { break }
        var iterator = sleeping.stream.makeAsyncIterator()
        let request = Task { await manager.performDataRequest(urlString: "https://example.test") }
        _ = await iterator.next()
        request.cancel()
        let result = await request.value
        if case .failure(.taskCancelled) = result {
        }
        else {
            Issue.record("Expected cancellation")
        }
        #expect(await requests.requests.count == 1)
        await manager.stopMonitoring()
        sleeping.continuation.finish()
    }

    @Test func successfulWaitReleasesItsObserver() async throws {
        let monitor = Monitor(connected: false)
        let manager = NetworkManager(makeMonitor: { monitor }, probeURL: nil)
        await manager.startMonitoring()
        let wait = Task { try await manager.waitForConnection(timeout: .seconds(2)) }
        await monitor.send(true)
        try await wait.value
        #expect(await manager.observerCount == 0)
        await manager.stopMonitoring()
    }

    @Test func cancelledStartDoesNotRestartMonitoring() async {
        let monitor = Monitor()
        let manager = NetworkManager(makeMonitor: { monitor }, probeURL: nil)
        let task = Task { await manager.startMonitoring() }
        task.cancel()
        await task.value
        #expect(await manager.state.isMonitoring == false)
        #expect(await monitor.callbacks.isEmpty == true)
    }

}
