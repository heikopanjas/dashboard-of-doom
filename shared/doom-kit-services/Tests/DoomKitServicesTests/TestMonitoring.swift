import DoomKitNetwork

struct TestMonitoring: NetworkMonitoring {
    func start(_ receive: @escaping @Sendable (Bool, ConnectionType) -> Void) async {
        receive(true, .wifi)
    }
    func stop() async {}
}
