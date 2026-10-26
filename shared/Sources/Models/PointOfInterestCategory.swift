import Foundation

enum PointOfInterestCategory: String, CaseIterable, Sendable {
    case pharmacies, hospitals, stores, funeralDirectors, cemeteries

    var title: String {
        switch self {
            case .pharmacies: return "Pharmacies"
            case .hospitals: return "Hospitals"
            case .stores: return "Liquor and convenience stores"
            case .funeralDirectors: return "Funeral directors"
            case .cemeteries: return "Cemeteries"
        }
    }

    var symbol: String {
        switch self {
            case .pharmacies: return "cross.case.fill"
            case .hospitals: return "cross.fill"
            case .stores: return "wineglass.fill"
            case .funeralDirectors: return "building.columns.fill"
            case .cemeteries: return "tree.fill"
        }
    }

    var preferenceKey: String { return "showPlaces.\(self.rawValue)" }
}
