/// A fresh adapter is created for each monitoring lifecycle.
public protocol NetworkMonitoring: Sendable {
    func start(_ receive: @escaping @Sendable (Bool, ConnectionType) -> Void) async
    func stop() async
}
