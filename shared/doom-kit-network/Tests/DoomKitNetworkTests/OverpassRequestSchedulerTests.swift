import Foundation
import Synchronization
import Testing

@testable import DoomKitNetwork

@Suite(.timeLimit(.minutes(1)))
struct OverpassRequestSchedulerTests {
    private actor Gate {
        var calls: [URLRequest] = []
        var continuation: CheckedContinuation<Void, Never>?
        func transport(_ request: URLRequest) async throws -> (Data, URLResponse) {
            self.calls.append(request)
            if self.calls.count == 1 { await withCheckedContinuation { self.continuation = $0 } }
            return try OverpassRequestSchedulerTests.response(request)
        }
        func release() {
            self.continuation?.resume()
            self.continuation = nil
        }
    }

    private static func request(_ name: String = "query") throws -> URLRequest {
        return URLRequest(url: try #require(URL(string: "https://overpass-api.de/api/interpreter?data=\(name)")))
    }

    private static func response(
        _ request: URLRequest, status: Int = 200, data: String = #"{"elements":[]}"#, headers: [String: String] = [:]
    ) throws -> (Data, URLResponse) {
        let url = try #require(request.url)
        return (Data(data.utf8), try #require(HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: headers)))
    }

    private func eventually(_ predicate: () async -> Bool) async throws {
        for _ in 0 ..< 2000 {
            if await predicate() == true { return }
            try await Task.sleep(for: .milliseconds(1))
        }
        throw URLError(.timedOut)
    }

    @Test func outageFallsBackAndRemembersFailedEndpoint() async throws {
        let calls = Mutex<[URLRequest]>([])
        let scheduler = OverpassRequestScheduler(
            transport: { request in
                calls.withLock { $0.append(request) }
                if request.url?.host == "overpass-api.de" { throw URLError(.cannotConnectToHost) }
                return try Self.response(request)
            }, sleep: { _ in try Task.checkCancellation() })
        #expect(try await scheduler.perform(Self.request("district"), priority: .userInitiated).get() == Data(#"{"elements":[]}"#.utf8))
        _ = await scheduler.perform(try Self.request("waterway"), priority: .userInitiated)
        let captured = calls.withLock { $0 }
        #expect(captured.map { $0.url?.host } == ["overpass-api.de", "overpass.private.coffee", "overpass.private.coffee"])
        #expect(captured[0].url?.query == captured[1].url?.query)
        #expect(captured.allSatisfy { $0.timeoutInterval == 35 })
    }

    @Test func rateLimitWaitsAndNeverRotatesEndpoints() async throws {
        let calls = Mutex<[URLRequest]>([])
        let delays = Mutex<[Duration]>([])
        let scheduler = OverpassRequestScheduler(
            transport: { request in
                calls.withLock { $0.append(request) }
                return try Self.response(request, status: 429, headers: ["Retry-After": "45"])
            }, sleep: { duration in delays.withLock { $0.append(duration) } })
        let result = await scheduler.perform(try Self.request(), priority: .userInitiated)
        if case .failure(.serverError(statusCode: 429)) = result {
        }
        else {
            Issue.record("Expected quota refusal")
        }
        #expect(calls.withLock { $0.count } == 2)
        #expect(calls.withLock { $0.allSatisfy { $0.url?.host == "overpass-api.de" } })
        let delay = try #require(delays.withLock { $0.first })
        #expect(delay > .seconds(44) && delay <= .seconds(45))
        let url = try #require(URL(string: "https://example.test"))
        let response = try #require(
            HTTPURLResponse(
                url: url, statusCode: 429, httpVersion: nil,
                headerFields: ["Retry-After": "Thu, 01 Jan 1970 00:02:00 GMT"]))
        #expect(OverpassRequestScheduler.retryDelay(response: response, now: Date(timeIntervalSince1970: 0)) == 120)
    }

    @Test func foregroundRequestsPrecedeQueuedPOIsAndCancellationReleasesWaiter() async throws {
        let gate = Gate()
        let scheduler = OverpassRequestScheduler(transport: { try await gate.transport($0) }, sleep: { _ in try Task.checkCancellation() })
        let first = Task { await scheduler.perform(try Self.request("first"), priority: .userInitiated) }
        try await self.eventually { await gate.calls.count == 1 }
        let background = Task { await scheduler.perform(try Self.request("poi"), priority: .background) }
        try await self.eventually { await scheduler.queuedCount == 1 }
        let cancelled = Task { await scheduler.perform(try Self.request("cancelled"), priority: .background) }
        try await self.eventually { await scheduler.queuedCount == 2 }
        cancelled.cancel()
        if case .failure(.taskCancelled) = try await cancelled.value {
        }
        else {
            Issue.record("Expected cancelled queue entry")
        }
        let foreground = Task { await scheduler.perform(try Self.request("district"), priority: .userInitiated) }
        try await self.eventually { await scheduler.queuedCount == 2 }
        #expect(await gate.calls.count == 1)
        await gate.release()
        _ = try await first.value
        _ = try await foreground.value
        _ = try await background.value
        #expect(await gate.calls.map { $0.url?.query } == ["data=first", "data=district", "data=poi"])
        #expect(await scheduler.queuedCount == 0)
    }

    @Test func activeCancellationDoesNotPoisonEndpointOrBlockNextRequest() async throws {
        let gate = Gate()
        let scheduler = OverpassRequestScheduler(transport: { try await gate.transport($0) }, sleep: { _ in try Task.checkCancellation() })
        let first = Task { await scheduler.perform(try Self.request(), priority: .userInitiated) }
        try await self.eventually { await gate.calls.count == 1 }
        first.cancel()
        let second = Task { await scheduler.perform(try Self.request(), priority: .userInitiated) }
        await gate.release()
        if case .failure(.taskCancelled) = try await first.value {
        }
        else {
            Issue.record("Late data published after cancellation")
        }
        _ = try await second.value.get()
        #expect(await gate.calls.allSatisfy { $0.url?.host == "overpass-api.de" })
    }

    @Test(arguments: [500, 504, 200]) func serverFailureAndRuntimeRemarksUseFallback(status: Int) async throws {
        let calls = Mutex<[URLRequest]>([])
        let scheduler = OverpassRequestScheduler(
            transport: { request in
                calls.withLock { $0.append(request) }
                if request.url?.host == "overpass-api.de" {
                    return try Self.response(request, status: status, data: #"{"elements":[],"remark":"runtime error: Query timed out"}"#)
                }
                return try Self.response(request)
            }, sleep: { _ in try Task.checkCancellation() })
        _ = try await scheduler.perform(Self.request(), priority: .userInitiated).get()
        #expect(calls.withLock { $0.count } == 2)
    }

    @Test func badQueryDoesNotRetryAndUnrelatedHTTPBypassesQueue() async throws {
        let calls = Mutex(0)
        let scheduler = OverpassRequestScheduler(
            transport: { request in
                calls.withLock { $0 += 1 }
                return try Self.response(request, status: 400)
            }, sleep: { _ in try Task.checkCancellation() })
        _ = await scheduler.perform(try Self.request(), priority: .userInitiated)
        #expect(calls.withLock { $0 } == 1)
        let gate = Gate()
        let monitor = NetworkManagerTests.Monitor()
        let manager = NetworkManager(
            transport: { request in
                if request.url?.host == "overpass-api.de" { return try await gate.transport(request) }
                return try Self.response(request)
            }, makeMonitor: { monitor }, probeURL: nil)
        await manager.startMonitoring()
        for await state in await manager.updates() where state.isConnected == true { break }
        let queued = Task { await manager.performDataRequest(urlString: "https://overpass-api.de/api/interpreter?data=first") }
        try await self.eventually { await gate.calls.count == 1 }
        #expect(try await manager.performDataRequest(urlString: "https://example.test/gauges").get() == Data(#"{"elements":[]}"#.utf8))
        await gate.release()
        _ = await queued.value
        await manager.stopMonitoring()
    }
}
