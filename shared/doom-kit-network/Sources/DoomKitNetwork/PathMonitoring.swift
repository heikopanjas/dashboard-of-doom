import Network

actor PathMonitoring: NetworkMonitoring {
    private var monitor: NWPathMonitor?

    func start(_ receive: @escaping @Sendable (Bool, ConnectionType) -> Void) {
        guard self.monitor == nil else { return }
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { path in
            let type: ConnectionType
            if path.usesInterfaceType(.wifi) == true {
                type = .wifi
            }
            else if path.usesInterfaceType(.cellular) == true {
                type = .cellular
            }
            else if path.usesInterfaceType(.wiredEthernet) == true {
                type = .ethernet
            }
            else {
                type = .unknown
            }
            receive(path.status == .satisfied, type)
        }
        self.monitor = monitor
        monitor.start(queue: DispatchQueue(label: "DoomKitNetwork.monitor"))
    }

    func stop() {
        self.monitor?.cancel()
        self.monitor = nil
    }

    deinit { self.monitor?.cancel() }
}
