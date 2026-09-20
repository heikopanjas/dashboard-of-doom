import SwiftUI

extension PointOfInterestCategory {
    var color: Color {
        switch self {
            case .pharmacies: return .green
            case .hospitals: return .red
            case .stores: return .cyan
            case .funeralDirectors: return .purple
            case .cemeteries: return .gray
        }
    }
}
