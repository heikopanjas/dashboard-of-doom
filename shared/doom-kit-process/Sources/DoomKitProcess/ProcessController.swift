import DoomKitLocation
import Foundation

public protocol ProcessController {
    func refreshData(for location: Location) async throws -> [ProcessSensor]
}

