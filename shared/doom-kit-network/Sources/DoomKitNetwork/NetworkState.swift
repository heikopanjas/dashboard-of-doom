public struct NetworkState: Sendable, Equatable {
    public var isInitialized: Bool
    public var isMonitoring: Bool
    public var isConnected: Bool
    public var connectionType: ConnectionType

    public init(
        isInitialized: Bool = false, isMonitoring: Bool = false,
        isConnected: Bool = false, connectionType: ConnectionType = .unknown
    ) {
        self.isInitialized = isInitialized
        self.isMonitoring = isMonitoring
        self.isConnected = isConnected
        self.connectionType = connectionType
    }
}
