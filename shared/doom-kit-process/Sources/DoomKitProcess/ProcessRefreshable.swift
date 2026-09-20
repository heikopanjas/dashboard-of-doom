import DoomKitLocation
import Foundation

@MainActor public protocol ProcessRefreshable: AnyObject, Identifiable where ID == UUID {
    func refreshData(location: Location) async
}
