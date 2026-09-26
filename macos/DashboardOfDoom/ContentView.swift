import SwiftUI

enum DashboardTab: String, CaseIterable {
    case home = "Home"
    case weather = "Weather"
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
        case .covid: return "facemask"
        case .level: return "water.waves"
        case .radiation: return "atom"
        case .particles: return "aqi.medium"
        case .energy: return "fuelpump"
        case .polls: return "chart.bar"
        }
    }

    /// Whether the tab is in the toolbar: a source's tab only while its switch is on. Home and Weather are always there, since weather
    /// always updates.
    func isVisible(defaults: UserDefaults = .standard) -> Bool {
        switch self {
        case .home, .weather: return true
        case .covid: return SourcePreferences.covidVisible(defaults: defaults)
        case .level: return SourcePreferences.waterVisible(defaults: defaults)
        case .radiation: return SourcePreferences.radiationVisible(defaults: defaults)
        case .particles: return SourcePreferences.particlesVisible(defaults: defaults)
        case .energy: return SourcePreferences.energyVisible(defaults: defaults)
        case .polls: return SourcePreferences.pollsVisible(defaults: defaults)
        }
    }
}

struct ContentView: View {
    @State private var selection: DashboardTab = .home

    // Observed so that a switch flipped in the Settings panel redraws the toolbar here at once; the visibility itself is read through
    // `DashboardTab.isVisible`, the same way the presenters read the switches.
    @AppStorage(SourcePreferences.covidEnableKey) private var showCovid: Bool = SourcePreferences.covidEnabledByDefault
    @AppStorage(SourcePreferences.waterKey) private var showLevels: Bool = true
    @AppStorage(SourcePreferences.radiationKey) private var showRadiation: Bool = true
    @AppStorage(SourcePreferences.particlesKey) private var showParticles: Bool = true
    @AppStorage(SourcePreferences.energyEnableKey) private var enableEnergy: Bool = SourcePreferences.energyEnabledByDefault
    @AppStorage(SourcePreferences.pollsEnableKey) private var showPolls: Bool = SourcePreferences.pollsEnabledByDefault

    private var switches: [Bool] {
        return [self.showCovid, self.showLevels, self.showRadiation, self.showParticles, self.enableEnergy, self.showPolls]
    }

    var body: some View {
        // Read here so the toolbar depends on the switches and redraws when one changes.
        let _ = self.switches
        VStack(spacing: 0) {
            HStack(spacing: 2) {
                ForEach(DashboardTab.allCases.filter { $0.isVisible() }, id: \.self) { tab in
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
        // A source switched off while its tab is on screen sends the dashboard back to Home.
        .onChange(of: self.switches) { _, _ in
            if self.selection.isVisible() == false {
                self.selection = .home
            }
        }
        .foregroundStyle(Color(light: .primary, dark: .cyan))
        .background(Color(light: .white, dark: Color(hex: "#000000")))
    }
}
