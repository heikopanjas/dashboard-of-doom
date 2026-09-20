import DoomKitNetwork
import DoomKitServices
import Foundation
import Synchronization
import Testing

struct ServiceTests {
    @Test(arguments: ServiceCase.all, [200, 503, -1])
    func requestsAndResults(service: ServiceCase, status: Int) async throws {
        let requests = Mutex<[URLRequest]>([])
        let bytes = Data([0, 255, 128, 10, 42])
        let manager = NetworkManager(
            transport: { request in
                requests.withLock { $0.append(request) }
                if status == -1 { throw CancellationError() }
                let url = try #require(request.url)
                let response = try #require(HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil))
                return (bytes, response)
            }, makeMonitor: { return TestMonitoring() }, sleep: { _ in try Task.checkCancellation() }, probeURL: nil)
        let updates = await manager.updates()
        await manager.startMonitoring()
        for await state in updates where state.isConnected == true {
            break
        }
        let result = try await service.fetch(manager)
        if status == 200 {
            #expect(result == bytes)
        }
        else {
            #expect(result == nil)
        }
        let captured = requests.withLock { $0 }
        let usesOverpass = service.url.hasPrefix("https://overpass-api.de/")
        #expect(captured.count == (status == 503 ? (usesOverpass == true ? 2 : 5) : 1))
        for (index, request) in captured.enumerated() {
            let expectedURL =
                usesOverpass == true && index == 1
                ? service.url.replacingOccurrences(of: "overpass-api.de", with: "overpass.private.coffee") : service.url
            #expect(request.url?.absoluteString == URL(string: expectedURL)?.absoluteString)
            #expect(request.httpMethod == "GET")
            #expect(request.httpBody == nil)
        }
        await manager.stopMonitoring()
    }

    @Test(arguments: ServiceCase.all)
    func cancelledBeforeRequest(service: ServiceCase) async throws {
        let manager = NetworkManager(
            transport: { _ in
                Issue.record("Cancelled fetch reached transport")
                throw CancellationError()
            }, makeMonitor: { return TestMonitoring() }, sleep: { _ in throw CancellationError() }, probeURL: nil)
        let result = try await Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await service.fetch(manager)
        }.value
        #expect(result == nil)
        #expect(await manager.state.isMonitoring == false)
    }
}
