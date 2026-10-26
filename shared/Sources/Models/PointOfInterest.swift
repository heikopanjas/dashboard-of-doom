import DoomKitLocation
import Foundation

struct PointOfInterest: Identifiable, Equatable, Sendable {
    let category: PointOfInterestCategory
    let elementType: String
    let elementID: Int64
    let name: String?
    let location: Location

    var id: String { return "\(self.category.rawValue):\(self.elementType):\(self.elementID)" }
}
