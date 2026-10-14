import Foundation

/// Stable identifiers for navigation and the saved toolbar assignments.
enum IOSScreen: String, Codable, CaseIterable {
    case home
    case weather
    case energy
    case particles
    case covid
    case level
    case radiation
    case surveys
    case settings

    static let customizable: [Self] = [.energy, .particles, .covid, .level, .radiation, .surveys]

    var label: String {
        switch self {
            case .home: return "Home"
            case .weather: return "Weather"
            case .energy: return "Energy"
            case .particles: return "Particles"
            case .covid: return "COVID-19"
            case .level: return "Level"
            case .radiation: return "Radiation"
            case .surveys: return "Election Polls"
            case .settings: return "Settings"
        }
    }

    func symbol(selected: Bool) -> String {
        switch self {
            case .home: return selected == true ? "house.fill" : "house"
            case .weather: return selected == true ? "cloud.bolt.fill" : "cloud.bolt"
            case .energy: return selected == true ? "fuelpump.fill" : "fuelpump"
            case .particles: return selected == true ? "aqi.medium" : "aqi.low"
            case .covid: return selected == true ? "facemask.fill" : "facemask"
            case .level: return "water.waves"
            case .radiation: return "atom"
            case .surveys: return selected == true ? "popcorn.fill" : "popcorn"
            case .settings: return selected == true ? "gearshape.fill" : "gearshape"
        }
    }
}
