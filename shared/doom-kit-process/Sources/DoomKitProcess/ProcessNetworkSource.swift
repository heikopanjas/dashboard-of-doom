import DoomKitNetwork

protocol ProcessNetworkSource: Sendable {
    func startMonitoring() async
    func updates() async -> AsyncStream<NetworkState>
    func waitForConnection(timeout: Duration) async throws
}

extension NetworkManager: ProcessNetworkSource {}
