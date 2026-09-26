import SwiftUI

enum DashboardTab: String, CaseIterable {
    case home = "Home"
    case weather = "Weather"
    case warnings = "Warnings"
    case covid = "COVID-19"
    case level = "Level"
    case radiation = "Radiation"
    case particles = "Particles"
    case energy = "Energy"
    case polls = "Polls"

    var icon: String {
        switch self {
        case .home: return "house"
        case .weather: return "cloud.sun"
        case .warnings: return "exclamationmark.triangle"
        case .covid: return "facemask"
        case .level: return "water.waves"
        case .radiation: return "atom"
        case .particles: return "aqi.medium"
        case .energy: return "fuelpump"
        case .polls: return "chart.bar"
        }
    }
}

struct ContentView: View {
    @State private var selection: DashboardTab = .home

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 2) {
                ForEach(DashboardTab.allCases, id: \.self) { tab in
                    ToolbarTabButton(
                        label: tab.rawValue,
                        icon: tab.icon,
                        isSelected: self.selection == tab,
                        action: { self.selection = tab }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 6)
            .background(Color(light: .white, dark: Color(hex: "#000000")))

            Divider()

            Group {
                switch self.selection {
                case .home:
                    HomeView().padding()
                case .weather:
                    ForecastView().padding()
                case .warnings:
                    WarningsView().padding()
                case .covid:
                    CovidView().padding()
                case .level:
                    LevelView().padding()
                case .radiation:
                    RadiationView().padding()
                case .particles:
                    ParticleView().padding()
                case .energy:
                    EnergyView().padding()
                case .polls:
                    SurveyView().padding()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(light: .white, dark: Color(hex: "#000000")))
        }
        .frame(minWidth: 700, minHeight: 720)
        .foregroundStyle(Color(light: .primary, dark: .cyan))
        .background(Color(light: .white, dark: Color(hex: "#000000")))
    }
}
