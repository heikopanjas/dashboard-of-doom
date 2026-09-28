import Charts
import MapKit
import SwiftUI

struct MapSizeModifier: ViewModifier {
    @ScaledMetric(relativeTo: .footnote) private var headerHeight = 36.0
    func body(content: Content) -> some View {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            content
                .frame(height: 667 + max(self.headerHeight - 36, 0))
        }
        else {
            content
                .frame(height: 367 + max(self.headerHeight - 36, 0))
        }
        #else
        content
            .frame(height: 500)
        #endif
    }
}

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(ColorPresenter.self) private var colors
    // One switch per source: off, its tab leaves the bar and, when it was on screen, the app goes back to Home.
    @AppStorage(SourcePreferences.pollsEnableKey) private var enableElectionPolls: Bool = SourcePreferences.pollsEnabledByDefault
    @AppStorage(SourcePreferences.covidEnableKey) private var enableCovid: Bool = SourcePreferences.covidEnabledByDefault
    @AppStorage(SourcePreferences.energyEnableKey) private var enableEnergy: Bool = SourcePreferences.energyEnabledByDefault
    @AppStorage(SourcePreferences.hazardsKey) private var showHazards: Bool = true
    @AppStorage(SourcePreferences.waterKey) private var showWater: Bool = true
    @AppStorage(SourcePreferences.radiationKey) private var showRadiation: Bool = true
    @AppStorage(SourcePreferences.particlesKey) private var showParticles: Bool = true
    @State private var selectedScreen = Screen.home
    @Environment(SimulationPresenter.self) private var simulation
    @State private var showsSimulation = false
    @State private var confirmsStop = false
    @State private var navigationVisible = Visibility.hidden
    @State private var navigationTitle = ""
    @State private var containerWidth: CGFloat = 0

    // The capsule draws about 5 points outside its content, so 21 leaves a 16 point gap to the screen edge.
    private let toolbarSideMargin: CGFloat = 21
    private let toolbarMaxWidth: CGFloat = 600

    /// iOS 26 sizes the bottom bar capsule to its content, so Spacer() cannot widen it.
    /// Nil until the first measurement, which leaves the system layout in place.
    private var toolbarWidth: CGFloat? {
        guard self.containerWidth > 0 else { return nil }
        return min(self.containerWidth - 2 * self.toolbarSideMargin, self.toolbarMaxWidth)
    }

    /// Whether a screen has anything to show. Environment holds level and radiation, so it stays while either is on.
    private func isAvailable(_ screen: Screen) -> Bool {
        switch screen {
            case .covid: return self.enableCovid
            case .energy: return self.enableEnergy
            case .environment: return self.showWater || self.showRadiation
            case .particles: return self.showParticles
            case .surveys: return self.enableElectionPolls
            case .home, .weather, .settings: return true
        }
    }

    /// Every source switch, so one handler notices any of them.
    private var switches: [Bool] {
        return [self.enableCovid, self.enableEnergy, self.showWater, self.showRadiation, self.showParticles, self.enableElectionPolls]
    }

    enum Screen {
        case home
        case weather
        case covid
        case energy
        case environment
        case particles
        case surveys
        case settings
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    HStack {
                        Group {
                            if self.colorScheme == .light {
                                Text(verbatim: "Dashboard of Doom")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                                    .frame(minHeight: 34, alignment: .leading)
                            }
                            else {
                                Image("dashboard-of-doom-logo")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 200, height: 34)
                                    .accessibilityLabel(Text(verbatim: "Dashboard of Doom"))
                            }
                        }
                        .padding(.top, 10)
                        .padding(.leading, 5)
                        .accessibilityAddTraits(.isHeader)
                        // The counterpart of the orange SIM tag in the macOS menu bar: on every screen while a place is simulated.
                        if self.simulation.isSimulating == true {
                            SimulationCapsule(name: self.simulation.placeName) {
                                self.confirmsStop = true
                            }
                            .padding(.top, 10)
                        }
                        Spacer()
                        self.simulationMenu
                            .padding(.top, 10)
                            .padding(.trailing, 5)
                    }
                    switch selectedScreen {
                        case .home:
                            VStack {
                                MapView()
                                    .padding(5)
                                    .padding(.trailing, 5)
                                    .modifier(MapSizeModifier())
                                Divider()
                                ForecastStripView()
                                    .padding(5)
                                    .padding(.trailing, 3)
                                Divider()
                                    .padding(.horizontal, 5)
                                    .padding(.trailing, 5)
                                CurrentConditionsView()
                                    .padding(5)
                                    .padding(.trailing, 3)
                                // Draws its own leading Divider, so nothing remains when places are off or empty.
                                NearestPlacesView()
                                if self.showHazards == true {
                                    Divider()
                                        .padding(.horizontal, 5)
                                        .padding(.trailing, 5)
                                    HazardCardView()
                                        .padding(5)
                                        .padding(.trailing, 3)
                                }
                            }
                            .onAppear {
                                navigationVisible = .visible
                                navigationTitle = "Home"
                            }
                        case .weather:
                            VStack {
                                ForecastView()
                                    .padding(5)
                                    .padding(.trailing, 3)
                            }
                            .onAppear {
                                navigationVisible = .visible
                                navigationTitle = "Weather Forecast"
                            }
                        case .covid:
                            if enableCovid == true {
                                VStack {
                                    // Draws its own trailing Divider, so nothing remains until the district has loaded.
                                    CovidMapView()
                                    CovidView()
                                        .padding(5)
                                        .padding(.trailing, 3)
                                }
                                .onAppear {
                                    navigationVisible = .visible
                                    navigationTitle = "COVID-19 Situation"
                                }
                            }
                        case .energy:
                            if enableEnergy == true {
                                VStack {
                                    // Renders nothing until a key is stored and stations have loaded.
                                    FuelMapView()
                                    EnergyView()
                                        .padding(5)
                                        .padding(.trailing, 3)
                                }
                                .onAppear {
                                    navigationVisible = .visible
                                    navigationTitle = "Energy Prices"
                                }
                            }
                        case .environment:
                            VStack {
                                // Draws its own trailing Divider, so nothing remains until a sensor has loaded. A source that is off has
                                // no labels on it and no section below it.
                                EnvironmentMapView()
                                if self.showRadiation == true {
                                    RadiationView()
                                        .padding(5)
                                        .padding(.trailing, 3)
                                }
                                if self.showRadiation == true && self.showWater == true {
                                    Divider()
                                        .padding(.horizontal, 5)
                                        .padding(.trailing, 5)
                                }
                                if self.showWater == true {
                                    LevelView()
                                        .padding(5)
                                        .padding(.trailing, 3)
                                }
                            }
                            .onAppear {
                                navigationVisible = .visible
                                navigationTitle = "Environmental Conditions"
                            }
                        case .particles:
                            VStack {
                                if self.showParticles == true {
                                    // Draws its own trailing Divider, so nothing remains until a station has loaded.
                                    ParticleMapView()
                                    ParticleView()
                                        .padding(5)
                                        .padding(.trailing, 3)
                                }
                            }
                            .onAppear {
                                navigationVisible = .visible
                                navigationTitle = "Particulate Matter"
                            }
                        case .surveys:
                            if enableElectionPolls == true {
                                VStack {
                                    SurveyView()
                                        .padding(5)
                                        .padding(.trailing, 3)
                                }
                                .onAppear {
                                    navigationVisible = .visible
                                    navigationTitle = "Election Polls"
                                }
                            }
                        case .settings:
                            VStack {
                                SettingsView()
                                    .padding(5)
                                    .padding(.trailing, 3)
                            }
                            .onAppear {
                                navigationVisible = .visible
                                navigationTitle = "Settings"
                            }
                    }
                }
                .frame(maxWidth: .infinity)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        HStack {
                            Text(navigationTitle)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .font(.headline)
                            Spacer()
                        }
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .bottomBar) {
                        HStack {
                            Button(action: { selectedScreen = .home }) {
                                Image(systemName: selectedScreen == .home ? "house.fill" : "house")
                                    .foregroundColor(selectedScreen == .home ? .accentColor : .accentColor.opacity(0.5))
                            }
                            .accessibilityLabel("Home")
                            Spacer()
                            Button(action: { selectedScreen = .weather }) {
                                Image(systemName: selectedScreen == .weather ? "cloud.bolt.fill" : "cloud.bolt")
                                    .foregroundColor(selectedScreen == .weather ? .accentColor : .accentColor.opacity(0.5))
                            }
                            .accessibilityLabel("Weather")
                            if enableEnergy == true {
                                Spacer()
                                Button(action: { selectedScreen = .energy }) {
                                    Image(systemName: selectedScreen == .energy ? "fuelpump.fill" : "fuelpump")
                                        .foregroundColor(selectedScreen == .energy ? .accentColor : .accentColor.opacity(0.5))
                                }
                                .accessibilityLabel("Energy")
                            }
                            if self.isAvailable(.environment) == true {
                                Spacer()
                                Button(action: { selectedScreen = .environment }) {
                                    Image(systemName: selectedScreen == .environment ? "leaf.fill" : "leaf")
                                        .foregroundColor(selectedScreen == .environment ? .accentColor : .accentColor.opacity(0.5))
                                }
                                .accessibilityLabel("Environment")
                            }
                            if self.isAvailable(.particles) == true {
                                Spacer()
                                Button(action: { selectedScreen = .particles }) {
                                    Image(systemName: selectedScreen == .particles ? "aqi.medium" : "aqi.low")
                                        .foregroundColor(selectedScreen == .particles ? .accentColor : .accentColor.opacity(0.5))
                                        .fontWeight(.black)  // Workaround for "aqi.medium" icon being rather thin
                                }
                                .accessibilityLabel("Particles")
                            }
                            if enableCovid == true {
                                Spacer()
                                Button(action: { selectedScreen = .covid }) {
                                    Image(systemName: selectedScreen == .covid ? "facemask.fill" : "facemask")
                                        .foregroundColor(selectedScreen == .covid ? .accentColor : .accentColor.opacity(0.5))
                                }
                                .accessibilityLabel("COVID-19")
                            }
                            if enableElectionPolls == true {
                                Spacer()
                                Button(action: { selectedScreen = .surveys }) {
                                    Image(systemName: selectedScreen == .surveys ? "popcorn.fill" : "popcorn")
                                        .foregroundColor(selectedScreen == .surveys ? .accentColor : .accentColor.opacity(0.5))
                                }
                            .accessibilityLabel("Election Polls")
                            }
                            Spacer()
                            Button(action: { selectedScreen = .settings }) {
                                Image(systemName: selectedScreen == .settings ? "gearshape.fill" : "gearshape")
                                    .foregroundColor(selectedScreen == .settings ? .accentColor : .accentColor.opacity(0.5))
                            }
                            .accessibilityLabel("Settings")
                        }
                        .frame(width: self.toolbarWidth)
                    }
                }
            }
            .onGeometryChange(for: CGFloat.self) {
                $0.size.width - $0.safeAreaInsets.leading - $0.safeAreaInsets.trailing
            } action: {
                self.containerWidth = $0
            }
            .toolbar(.hidden, for: .navigationBar)
            .toolbarBackground(.visible, for: .bottomBar)
            .toolbarBackground(
                Color(
                    uiColor: UIColor { traitCollection in
                        traitCollection.userInterfaceStyle == .dark ? .black : .white
                    }), for: .bottomBar
            )
            .onChange(of: self.switches) { _, _ in
                if self.isAvailable(self.selectedScreen) == false {
                    self.selectedScreen = .home
                }
            }
            .refreshable {
                if self.selectedScreen != .settings {
                    AppProcess.shared.refreshSubscriptions()
                }
            }
            .sheet(isPresented: self.$showsSimulation) {
                NavigationStack {
                    SimulationView(start: AppLocation.shared.state.location) { location, name in
                        self.simulation.start(location, name: name)
                        self.showsSimulation = false
                    }
                    .navigationTitle("Simulation")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                self.showsSimulation = false
                            }
                        }
                    }
                }
            }
            .confirmationDialog("Stop the simulation?", isPresented: self.$confirmsStop, titleVisibility: .visible) {
                Button("Stop Simulation", role: .destructive) {
                    self.simulation.stop()
                }
            } message: {
                Text("The app goes back to where you are.")
            }
        }
        .tint(self.colors.tint(for: self.colorScheme))
    }

    /// The same two entries as the macOS menu: Simulation… opens the sheet, also while simulating, so one place can follow another;
    /// Stop Simulation goes back to the real location and is disabled while nothing is simulated.
    private var simulationMenu: some View {
        Menu {
            Button("Simulation…", systemImage: "location.magnifyingglass") {
                self.showsSimulation = true
            }
            Button("Stop Simulation", systemImage: "location.slash", role: .destructive) {
                self.simulation.stop()
            }
            .disabled(self.simulation.isSimulating == false)
        } label: {
            Image(systemName: "location.magnifyingglass")
                .font(.title3)
                .frame(minWidth: 44, minHeight: 34)
        }
        .accessibilityLabel("Simulation")
    }
}
