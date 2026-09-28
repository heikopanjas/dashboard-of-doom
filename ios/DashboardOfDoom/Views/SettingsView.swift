import DoomKitProcess
import DoomKitLocation
import DoomKitTools
import SwiftUI

struct SettingsView: View {
    @Environment(PointOfInterestPresenter.self) private var pointsOfInterest
    @Environment(ColorPresenter.self) private var colors
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("enableDarkTheme") private var enableDarkTheme: Bool = false

    @AppStorage("showWeather") private var showWeather: Bool = true
    @AppStorage(SourcePreferences.covidEnableKey) private var enableCovid: Bool = SourcePreferences.covidEnabledByDefault
    @AppStorage(SourcePreferences.energyEnableKey) private var enableEnergy: Bool = SourcePreferences.energyEnabledByDefault
    @Environment(FuelPresenter.self) private var fuel
    @AppStorage(SourcePreferences.fuelTypeKey) private var fuelType: Int = FuelStation.Fuel.e5.rawValue
    @AppStorage(SourcePreferences.fuelOrderKey) private var fuelOrder: Int = FuelMapView.Order.dearest.rawValue
    @AppStorage(SourcePreferences.fuelRadiusKey) private var fuelRadius: Int = SourcePreferences.fuelRadiusDefault
    @AppStorage(SourcePreferences.fuelOpenOnlyKey) private var fuelOpenOnly: Bool = true
    @State private var hasFuelKey = false
    @AppStorage(SourcePreferences.radiationKey) private var showRadiation: Bool = true
    @AppStorage(SourcePreferences.hazardsKey) private var showHazards: Bool = true
    @AppStorage(SourcePreferences.forecastsKey) private var showForecasts: Bool = SourcePreferences.forecastsEnabledByDefault

    @Environment(WeatherPresenter.self) private var weather
    @Environment(CovidPresenter.self) private var covid
    @Environment(RadiationPresenter.self) private var radiation
    @AppStorage(SourcePreferences.multiSensorRadiationKey) private var multiSensorRadiation: Bool = false

    @Environment(LevelPresenter.self) private var level
    @AppStorage("showWater") private var showWater: Bool = true
    @AppStorage(SourcePreferences.nearestLevelSensorKey) private var nearestLevelSensor: Bool = false
    @AppStorage(SourcePreferences.multiSensorLevelKey) private var multiSensorLevel: Bool = false
    @AppStorage(SourcePreferences.multiSensorLevelOtherWaterwaysKey) private var multiSensorLevelOtherWaterways: Bool = false

    @Environment(ParticlePresenter.self) private var particles
    @AppStorage(SourcePreferences.particlesKey) private var showParticles: Bool = true
    @AppStorage(SourcePreferences.nearestParticleSensorKey) private var nearestParticleSensor: Bool = false
    @AppStorage(SourcePreferences.multiSensorParticlesKey) private var multiSensorParticles: Bool = false

    @Environment(SurveyPresenter.self) private var electionPolls
    @AppStorage("enableElectionPolls") private var enableElectionPolls: Bool = false
    @AppStorage("electionPollScope") private var electionPollScope: Int = 1

    /// The waterway choice over the two stored level switches, which keep their historical keys.
    private var levelWaterways: Binding<SourcePreferences.LevelWaterways> {
        return Binding(
            get: {
                SourcePreferences.LevelWaterways(
                    nearest: self.nearestLevelSensor, otherWaterways: self.multiSensorLevelOtherWaterways, multiSensor: self.multiSensorLevel)
            },
            set: { choice in
                self.nearestLevelSensor = choice.switches.nearest
                self.multiSensorLevelOtherWaterways = choice.switches.otherWaterways
            })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("General")
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.bottom, 4)

            VStack(spacing: 12) {
                Toggle("Always Use Dark Theme", isOn: $enableDarkTheme)
                HStack {
                    Text("Use the dark theme even when iOS is set to light.")
                        .font(.footnote)
                        .foregroundColor(.gray)
                    Spacer()
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)

            if self.colorScheme == .dark {
                VStack(spacing: 12) {
                    HStack {
                        Text("Accent Color")
                        Spacer()
                    }
                    HStack(spacing: 12) {
                        ForEach(ColorPresenter.accents) { accent in
                            Button {
                                self.colors.selectAccent(accent.id)
                            } label: {
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(accent.color)
                                    .frame(width: 33, height: 33)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 5)
                                            .stroke(
                                                self.colors.selectedAccent.id == accent.id ? Color.primary : Color.clear,
                                                lineWidth: 2)
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(accent.label)
                            .accessibilityAddTraits(self.colors.selectedAccent.id == accent.id ? [.isSelected] : [])
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    HStack {
                        Text("Tints icons, charts and headings. Light mode always uses the standard blue.")
                            .font(.footnote)
                            .foregroundColor(.gray)
                        Spacer()
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
            }
        }

        // One switch per source. On, it updates and shows on the map and in its tab; off, it stops updating and its tab and label go.
        VStack(alignment: .leading, spacing: 8) {
            Text("Sources")
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.bottom, 4)
            VStack(spacing: 12) {
                Toggle("COVID-19", isOn: $enableCovid)
                Toggle("Water", isOn: $showWater)
                Toggle("Radiation", isOn: $showRadiation)
                Toggle("Particulate Matter", isOn: $showParticles)
                Toggle("Warnings", isOn: $showHazards)
                Toggle("Energy", isOn: $enableEnergy)
                Toggle("Election Polls", isOn: $enableElectionPolls)
                HStack {
                    Text("A source that is on keeps updating, shows its value on the map and has its tab; warnings show on the Home screen. Turning one off stops it and removes its tab and its label. Weather always updates.")
                        .font(.footnote)
                        .foregroundColor(.gray)
                    Spacer()
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }

        // One switch for every source's forecast; it is not a source switch and removes no tab.
        VStack(alignment: .leading, spacing: 8) {
            Text("Forecasts")
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.bottom, 4)
            VStack(spacing: 12) {
                Toggle("Show Forecasts", isOn: $showForecasts)
                    .onChange(of: showForecasts) { _, _ in
                        // Only the sources that fetch a forecast need to refresh; the charts hide or show what they have at once.
                        AppProcess.shared.refreshSubscription(subscriber: particles)
                        AppProcess.shared.refreshSubscription(subscriber: level)
                    }
                HStack {
                    Text(ForecastDisplay.settingsExplanation)
                        .font(.footnote)
                        .foregroundColor(.gray)
                    Spacer()
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }

        VStack(alignment: .leading, spacing: 8) {
            Text("Home")
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.bottom, 4)
            VStack(spacing: 12) {
                Toggle("Weather", isOn: $showWeather)
                HStack {
                    Text("Shows the temperature on the map. Weather keeps updating either way.")
                        .font(.footnote)
                        .foregroundColor(.gray)
                    Spacer()
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
        NotificationSettingsView()

        VStack(alignment: .leading, spacing: 8) {
            Text("Points of Interest")
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.bottom, 4)
            PointOfInterestSettingsView(presenter: self.pointsOfInterest)
        }

        LocationSettingsView()

        // Only while the source is on; its switch is in the Sources card.
        if showWater == true {
        VStack(alignment: .leading, spacing: 8) {
            Text("Water")
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.bottom, 4)
            VStack(spacing: 12) {
                Toggle("Multiple Sensors", isOn: $multiSensorLevel)
                    .onChange(of: multiSensorLevel) { _, _ in
                        AppProcess.shared.refreshSubscription(subscriber: level)
                    }
                HStack {
                    Text(
                        "Show up to \(ProcessSensor.maximumPerSource) gauges, nearest first, on the Environment tab. Otherwise only the nearest gauge is loaded. The map on the home screen shows only the nearest one."
                    )
                    .font(.footnote)
                    .foregroundColor(.gray)
                    Spacer()
                }
                // One choice over two stored switches; Natural First is only offered with extra gauges, since without them it is Natural.
                Picker("Waterways", selection: self.levelWaterways) {
                    ForEach(SourcePreferences.LevelWaterways.choices(multiSensor: multiSensorLevel), id: \.self) { choice in
                        Text(choice.label).tag(choice)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: nearestLevelSensor) { _, _ in
                    AppProcess.shared.refreshSubscription(subscriber: level)
                }
                .onChange(of: multiSensorLevelOtherWaterways) { _, _ in
                    AppProcess.shared.refreshSubscription(subscriber: level)
                }
                HStack {
                    Text("\(self.levelWaterways.wrappedValue.explanation) The map on the home screen always shows the first gauge.")
                        .font(.footnote)
                        .foregroundColor(.gray)
                    Spacer()
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
        }
        // Only while the source is on; its switch is in the Sources card.
        if showRadiation == true {
        VStack(alignment: .leading, spacing: 8) {
            Text("Radiation")
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.bottom, 4)
            VStack(spacing: 12) {
                Toggle("Multiple Sensors", isOn: $multiSensorRadiation)
                    .onChange(of: multiSensorRadiation) { _, _ in
                        AppProcess.shared.refreshSubscription(subscriber: radiation)
                    }
                HStack {
                    Text(
                        "Show up to \(ProcessSensor.maximumPerSource) measuring stations, nearest first, on the Environment tab. Otherwise only the nearest station is loaded. The map on the home screen shows only the nearest one."
                    )
                    .font(.footnote)
                    .foregroundColor(.gray)
                    Spacer()
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
        }
        // Only while the source is on; its switch is in the Sources card.
        if showParticles == true {
        VStack(alignment: .leading, spacing: 8) {
            Text("Particulate Matter")
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.bottom, 4)
            VStack(spacing: 12) {
                Toggle("Any Station", isOn: $nearestParticleSensor)
                    .onChange(of: nearestParticleSensor) { _, _ in
                        AppProcess.shared.refreshSubscription(subscriber: particles)
                    }
                HStack {
                    Text(
                        "Use the closest stations even if they measure fewer or other pollutants. Otherwise only stations reporting \u{1D40F}\u{1D40C}\u{2081}\u{2080}, \u{1D40F}\u{1D40C}\u{2082}\u{2085}, \u{1D40E}\u{2083} and \u{1D40D}\u{1D40E}\u{2082} are shown, nearest first, which can mean fewer of them."
                    )
                    .font(.footnote)
                    .foregroundColor(.gray)
                    Spacer()
                }
                Toggle("Multiple Sensors", isOn: $multiSensorParticles)
                    .onChange(of: multiSensorParticles) { _, _ in
                        AppProcess.shared.refreshSubscription(subscriber: particles)
                    }
                HStack {
                    Text(
                        "Show up to \(SourcePreferences.sensorMaximum(forKey: SourcePreferences.multiSensorParticlesKey)) stations, nearest first, on the Particles tab. Otherwise only the nearest station is loaded, which needs fewer requests. The map on the home screen shows only the nearest one."
                    )
                    .font(.footnote)
                    .foregroundColor(.gray)
                    Spacer()
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
        }

        // Only while the source is on; its switch is in the Sources card.
        if enableEnergy == true {
        VStack(alignment: .leading, spacing: 8) {
            Text("Energy")
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.bottom, 4)
            VStack(spacing: 12) {
                if enableEnergy == true {
                    VStack(spacing: 12) {
                        // Saving a key is a keychain write, which nothing observes, so the stations are refreshed by hand.
                        SecretField(
                            label: "Tankerkoenig API key", key: FuelController.apiKeyName,
                            onChange: {
                                self.hasFuelKey = AppSecrets.shared.contains(FuelController.apiKeyName)
                                AppProcess.shared.refreshSubscription(subscriber: self.fuel)
                            })
                        HStack {
                            Text(
                                "Puts a map of the dearest filling stations near you at the top of the Energy tab. A key is free from creativecommons.tankerkoenig.de and is kept in the keychain, never in the app."
                            )
                            .font(.footnote)
                            .foregroundColor(.gray)
                            Spacer()
                        }
                        if hasFuelKey == true {
                            Picker("Fuel", selection: $fuelType) {
                                ForEach(FuelStation.Fuel.allCases, id: \.rawValue) { fuel in
                                    Text(fuel.label).tag(fuel.rawValue)
                                }
                            }
                            .pickerStyle(.segmented)
                            Picker("Order", selection: $fuelOrder) {
                                ForEach(FuelMapView.Order.allCases, id: \.rawValue) { order in
                                    Text(order.label).tag(order.rawValue)
                                }
                            }
                            .pickerStyle(.segmented)
                            HStack {
                                Text("Which fuel the map shows and which end of the price range. All three prices are already loaded, so these change the map at once.")
                                    .font(.footnote)
                                    .foregroundColor(.gray)
                                Spacer()
                            }
                            // A new radius is a different request, so this one refetches.
                            Picker("Radius", selection: $fuelRadius) {
                                ForEach(SourcePreferences.fuelRadiusChoices, id: \.self) { kilometres in
                                    Text("\(kilometres) km").tag(kilometres)
                                }
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: fuelRadius) { _, _ in
                                AppProcess.shared.refreshSubscription(subscriber: self.fuel)
                            }
                            HStack {
                                Text("How far around you to look. Tankerkoenig searches at most 25 km.")
                                    .font(.footnote)
                                    .foregroundColor(.gray)
                                Spacer()
                            }
                            // Tankerkoenig allows no filtering the user did not ask for, so leaving out closed stations is a switch.
                            Toggle("Open Stations Only", isOn: $fuelOpenOnly)
                            HStack {
                                Text("Leave out stations that are closed right now. Off, they are ranked too and marked with a lock.")
                                    .font(.footnote)
                                    .foregroundColor(.gray)
                                Spacer()
                            }
                        }
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .onAppear {
                self.hasFuelKey = AppSecrets.shared.contains(FuelController.apiKeyName)
            }
        }
        }


        // Only while the source is on; its switch is in the Sources card.
        if enableElectionPolls == true {
        VStack(alignment: .leading, spacing: 8) {
            Text("Election Polls")
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.bottom, 4)
            VStack(spacing: 12) {
                if enableElectionPolls == true {
                    Picker("Scope", selection: $electionPollScope) {
                        Text("Federal").tag(0)
                        Text("State").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: electionPollScope) { _, _ in
                                                AppProcess.shared.refreshSubscription(subscriber: electionPolls)
                    }
                    HStack {
                        Text("Federal covers the Bundestag. State covers the parliament where you are.")
                            .font(.footnote)
                            .foregroundColor(.gray)
                        Spacer()
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
        }

        AboutSettingsView()
    }
}
