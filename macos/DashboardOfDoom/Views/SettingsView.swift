import DoomKitProcess
import KeyboardShortcuts
import LaunchAtLogin
import SwiftUI

// MARK: - Settings Tab

enum SettingsTab: String, CaseIterable {
    case general = "General"
    case weather = "Weather"
    case warnings = "Warnings"
    case covid = "COVID-19"
    case level = "Level"
    case radiation = "Radiation"
    case particles = "Particles"
    case energy = "Energy"
    case polls = "Polls"
    case places = "Places"
    case notifications = "Notify"
    case about = "About"

    var icon: String {
        switch self {
        case .general: return "gear"
        case .weather: return "cloud.sun"
        case .warnings: return "exclamationmark.triangle"
        case .covid: return "facemask"
        case .level: return "water.waves"
        case .radiation: return "atom"
        case .particles: return "aqi.medium"
        case .energy: return "fuelpump"
        case .polls: return "chart.bar"
        case .places: return "mappin.and.ellipse"
        case .notifications: return "bell"
        case .about: return "info.circle"
        }
    }
}

// MARK: - Settings Selection

/// Externally drivable tab selection. The settings panel is cached, so opening it
/// a second time has to switch the tab of a view that already exists.
@MainActor @Observable
final class SettingsSelection {
    var tab: SettingsTab = .general
}

// MARK: - Refresh Rate Picker

struct RefreshRatePicker: View {
    let label: String
    @Binding var interval: Int

    private let intervals: [(label: String, minutes: Int)] = [
        ("5 minutes", 5),
        ("15 minutes", 15),
        ("30 minutes", 30),
        ("1 hour", 60),
        ("6 hours", 360)
    ]

    var body: some View {
        Picker(label, selection: $interval) {
            ForEach(intervals, id: \.minutes) { option in
                Text(option.label).tag(option.minutes)
            }
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    /// Wide enough for all twelve tab buttons in one row.
    static let width: CGFloat = 840

    let selection: SettingsSelection

    // Presenters for triggering refreshes when settings change
    let levelPresenter: LevelPresenter
    let particlePresenter: ParticlePresenter
    let surveyPresenter: SurveyPresenter
    let fuelPresenter: FuelPresenter
    let pointOfInterestPresenter: PointOfInterestPresenter

    // Enable toggles
    @AppStorage("showWeather") private var showWeather: Bool = true
    @AppStorage("showCovid") private var showCovid: Bool = true
    @AppStorage("showLevels") private var showLevels: Bool = true
    @AppStorage("showRadiation") private var showRadiation: Bool = true
    @AppStorage("showParticles") private var showParticles: Bool = true
    @AppStorage("showElectionPolls") private var showElectionPolls: Bool = true
    @AppStorage("showHazards") private var showHazards: Bool = true
    @AppStorage(SourcePreferences.energyEnableKey) private var enableEnergy: Bool = SourcePreferences.energyEnabledByDefault

    // Fuel stations: which fuel, which end of the price range and how far. Ranking is local, so only the radius refetches.
    @AppStorage(SourcePreferences.fuelTypeKey) private var fuelType: Int = FuelStation.Fuel.e5.rawValue
    @AppStorage(SourcePreferences.fuelOrderKey) private var fuelOrder: Int = FuelMapView.Order.dearest.rawValue
    @AppStorage(SourcePreferences.fuelRadiusKey) private var fuelRadius: Int = SourcePreferences.fuelRadiusDefault
    @State private var hasFuelKey = false

    // Sensor preferences
    @AppStorage("nearestLevelSensor") private var nearestLevelSensor: Bool = false
    @AppStorage("nearestParticleSensor") private var nearestParticleSensor: Bool = false

    // Election poll scope
    @AppStorage("electionPollScope") private var electionPollScope: Int = 1

    // Appearance
    @AppStorage("alwaysUseDarkTheme") private var alwaysUseDarkTheme: Bool = true

    // Refresh intervals (in minutes)
    @AppStorage("weatherRefreshInterval") private var weatherRefreshInterval: Int = 5
    @AppStorage("covidRefreshInterval") private var covidRefreshInterval: Int = 360
    @AppStorage("levelRefreshInterval") private var levelRefreshInterval: Int = 15
    @AppStorage("radiationRefreshInterval") private var radiationRefreshInterval: Int = 15
    @AppStorage("particleRefreshInterval") private var particleRefreshInterval: Int = 30
    @AppStorage("surveyRefreshInterval") private var surveyRefreshInterval: Int = 360
    @AppStorage("hazardRefreshInterval") private var hazardRefreshInterval: Int = 15
    @AppStorage("energyRefreshInterval") private var energyRefreshInterval: Int = 360
    @AppStorage("fuelRefreshInterval") private var fuelRefreshInterval: Int = 60

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 2) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    ToolbarTabButton(
                        label: tab.rawValue,
                        icon: tab.icon,
                        isSelected: self.selection.tab == tab,
                        action: { self.selection.tab = tab }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 6)

            Divider()

            // Content
            Group {
                switch self.selection.tab {
                case .general:
                    generalContent
                case .weather:
                    weatherContent
                case .warnings:
                    warningsContent
                case .covid:
                    covidContent
                case .level:
                    levelContent
                case .radiation:
                    radiationContent
                case .particles:
                    particlesContent
                case .energy:
                    energyContent
                case .polls:
                    pollsContent
                case .places:
                    PointOfInterestSettingsView(presenter: self.pointOfInterestPresenter)
                case .notifications:
                    NotificationSettingsView(levelPresenter: self.levelPresenter)
                case .about:
                    aboutContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: Self.width, height: 400)
        .background(Color(light: .white, dark: Color(hex: "#000000")))
        .onChange(of: nearestLevelSensor) { _, _ in
            AppProcess.shared.refreshSubscription(subscriber: self.levelPresenter)
        }
        .onChange(of: nearestParticleSensor) { _, _ in
            AppProcess.shared.refreshSubscription(subscriber: self.particlePresenter)
        }
        .onChange(of: electionPollScope) { _, _ in
            AppProcess.shared.refreshSubscription(subscriber: self.surveyPresenter)
        }
        .onChange(of: fuelRadius) { _, _ in
            AppProcess.shared.refreshSubscription(subscriber: self.fuelPresenter)
        }
    }

    // MARK: - Tab Content Views

    private var generalContent: some View {
        Form {
            Section("Application") {
                LaunchAtLogin.Toggle("Launch at Login")
            }
            Section("Keyboard Shortcut") {
                KeyboardShortcuts.Recorder("Toggle Dashboard:", name: .toggleDashboard)
            }
            Section("Appearance") {
                Toggle("Always Use Dark Theme", isOn: $alwaysUseDarkTheme)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private var weatherContent: some View {
        Form {
            Section("Data Source") {
                Toggle("Enable Weather Data", isOn: $showWeather)
            }
            Section("Refresh") {
                RefreshRatePicker(label: "Update Interval", interval: $weatherRefreshInterval)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private var warningsContent: some View {
        Form {
            Section("Data Source") {
                Toggle("Enable Warnings", isOn: $showHazards)
                    .help("Official NINA warnings from the DWD, MoWaS, KATWARN and BIWAPP feeds that cover your location or lie nearby")
            }
            Section("Refresh") {
                RefreshRatePicker(label: "Update Interval", interval: $hazardRefreshInterval)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private var covidContent: some View {
        Form {
            Section("Data Source") {
                Toggle("Enable COVID-19 Data", isOn: $showCovid)
            }
            Section("Refresh") {
                RefreshRatePicker(label: "Update Interval", interval: $covidRefreshInterval)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private var levelContent: some View {
        Form {
            Section("Data Source") {
                Toggle("Enable Water Level Data", isOn: $showLevels)
            }
            Section("Sensor") {
                Toggle("Use Nearest Sensor", isOn: $nearestLevelSensor)
                    .help("When enabled, shows data from the closest water level sensor to your location")
            }
            Section("Refresh") {
                RefreshRatePicker(label: "Update Interval", interval: $levelRefreshInterval)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private var radiationContent: some View {
        Form {
            Section("Data Source") {
                Toggle("Enable Radiation Data", isOn: $showRadiation)
            }
            Section("Refresh") {
                RefreshRatePicker(label: "Update Interval", interval: $radiationRefreshInterval)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private var particlesContent: some View {
        Form {
            Section("Data Source") {
                Toggle("Enable Particulate Matter Data", isOn: $showParticles)
            }
            Section("Sensor") {
                Toggle("Use Nearest Sensor", isOn: $nearestParticleSensor)
                    .help("When enabled, shows data from the closest air quality sensor to your location")
            }
            Section("Refresh") {
                RefreshRatePicker(label: "Update Interval", interval: $particleRefreshInterval)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private var energyContent: some View {
        Form {
            Section("Data Source") {
                Toggle("Enable Energy Prices", isOn: $enableEnergy)
                    .help("Daily Brent and WTI crude oil prices and the EU LNG price. Also governs the fuel station map")
            }
            if self.enableEnergy == true {
                Section("Fuel Stations") {
                    // Saving a key is a keychain write, which nothing observes, so the stations are refreshed by hand.
                    SecretField(
                        label: "Tankerkoenig API key", key: FuelController.apiKeyName,
                        onChange: {
                            self.hasFuelKey = AppSecrets.shared.contains(FuelController.apiKeyName)
                            AppProcess.shared.refreshSubscription(subscriber: self.fuelPresenter)
                        })
                    Text(
                        "Puts a map of the dearest filling stations near you at the top of the Energy tab. A key is free from creativecommons.tankerkoenig.de and is kept in the keychain, never in the app."
                    )
                    .font(.footnote)
                    .foregroundColor(.gray)
                    if self.hasFuelKey == true {
                        Picker("Fuel", selection: $fuelType) {
                            ForEach(FuelStation.Fuel.allCases, id: \.rawValue) { fuel in
                                Text(fuel.label).tag(fuel.rawValue)
                            }
                        }
                        Picker("Order", selection: $fuelOrder) {
                            ForEach(FuelMapView.Order.allCases, id: \.rawValue) { order in
                                Text(order.label).tag(order.rawValue)
                            }
                        }
                        Picker("Radius", selection: $fuelRadius) {
                            ForEach(SourcePreferences.fuelRadiusChoices, id: \.self) { kilometres in
                                Text("\(kilometres) km").tag(kilometres)
                            }
                        }
                        .help("How far around you to look. Tankerkoenig searches at most 25 km")
                    }
                }
            }
            Section("Refresh") {
                RefreshRatePicker(label: "Price Interval", interval: $energyRefreshInterval)
                RefreshRatePicker(label: "Fuel Station Interval", interval: $fuelRefreshInterval)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .onAppear {
            self.hasFuelKey = AppSecrets.shared.contains(FuelController.apiKeyName)
        }
    }

    private var pollsContent: some View {
        Form {
            Section("Data Source") {
                Toggle("Enable Election Poll Data", isOn: $showElectionPolls)
            }
            Section("Scope") {
                Picker("Poll Scope", selection: $electionPollScope) {
                    Text("Federal").tag(0)
                    Text("State").tag(1)
                }
                .pickerStyle(.radioGroup)
            }
            Section("Refresh") {
                RefreshRatePicker(label: "Update Interval", interval: $surveyRefreshInterval)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private var aboutContent: some View {
        VStack(spacing: 12) {
            Spacer()

            Text("Dashboard of Doom")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"))")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("A macOS menu bar application providing real-time environmental and public health data for Germany. Integrates weather, civil protection warnings, air quality, water levels, radiation, COVID-19 statistics, energy and fuel prices, and election polls.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            Text("COVID-19 district boundaries: © BKG (\(Calendar.current.component(.year, from: Date()))) dl-de/by-2-0")
                .font(.caption2)
                .foregroundColor(.secondary)

            Text("Berlin borough boundaries: Amt für Statistik Berlin-Brandenburg, CC-BY")
                .font(.caption2)
                .foregroundColor(.secondary)

            Text("Federal waterway network: © WSV (GDWS), VerkNet-BWaStr")
                .font(.caption2)
                .foregroundColor(.secondary)

            Text("Fuel prices: tankerkoenig.de, CC BY 4.0, data from MTS-K")
                .font(.caption2)
                .foregroundColor(.secondary)

            Text("© 2025 Heiko Panjas. All rights reserved.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
