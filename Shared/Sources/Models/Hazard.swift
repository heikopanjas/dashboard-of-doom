import DoomKitLocation
import DoomKitServices
import Foundation

/// One active NINA warning, placed relative to the user.
struct Hazard: Identifiable, Equatable, Sendable {
    /// CAP severity, ordered so that a higher case is more serious.
    enum Severity: Int, Comparable, Sendable {
        case unknown = 0, minor, moderate, severe, extreme

        init(cap: String?) {
            switch cap?.lowercased() {
                case "minor": self = .minor
                case "moderate": self = .moderate
                case "severe": self = .severe
                case "extreme": self = .extreme
                default: self = .unknown
            }
        }

        var label: String {
            switch self {
                case .unknown: return "Unknown"
                case .minor: return "Minor"
                case .moderate: return "Moderate"
                case .severe: return "Severe"
                case .extreme: return "Extreme"
            }
        }

        static func < (lhs: Self, rhs: Self) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }

    let id: String
    let feed: HazardFeed
    let event: String?
    let headline: String
    let description: String
    let instruction: String?
    let severity: Severity
    let sent: Date
    let expires: Date?
    let areaDescription: String?
    /// The user's location when inside the warning area, else the nearest point on its edge.
    let location: Location
    /// Metres from the user to the warning area, 0 when inside.
    let distance: Double
    var placemark: String?

    var isInside: Bool { return self.distance == 0 }

    /// The alert's own page on NINA, in the form the NINA web app links to:
    /// `/meldungen/{list id}/{slug}/`. The slug is free text; the shorter
    /// `/meldung/{id}/` redirect route loses the alert. The CAP `web` field
    /// is not used: DWD sets it to a generic page and some issuers leave it empty.
    var sourceURL: URL? {
        let path = self.id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? self.id
        return URL(string: "https://warnung.bund.de/meldungen/\(path)/warnung/")
    }

    var areaLabel: String {
        let area = self.areaDescription ?? self.placemark ?? "Nearby"
        return self.isInside ? area : String(format: "%@ · %.0f km", area, self.distance / 1000)
    }
}
