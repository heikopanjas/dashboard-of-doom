import DoomKitNetwork
import DoomKitProcess

@MainActor
enum AppProcess {
    static let shared: ProcessCoordinator = {
        #if os(iOS)
        return ProcessCoordinator(
            locationManager: AppLocation.shared, networkManager: NetworkManager.shared, locationRefreshPolicy: .everyMovement)
        #else
        let coordinator = ProcessCoordinator(locationManager: AppLocation.shared, networkManager: NetworkManager.shared)
        coordinator.start()
        return coordinator
        #endif
    }()
}
