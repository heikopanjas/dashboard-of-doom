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
    @AppStorage("showCovid") private var showCovid: Bool = true
    @AppStorage("showRadiation") private var showRadiation: Bool = true

    @Environment(WeatherPresenter.self) private var weather
    @Environment(CovidPresenter.self) private var covid
    @Environment(RadiationPresenter.self) private var radiation

    @Environment(LevelPresenter.self) private var level
    @AppStorage("showWater") private var showWater: Bool = true
    @AppStorage("nearestLevelSensor") private var nearestLevelSensor: Bool = false

    @Environment(ParticlePresenter.self) private var particles
    @AppStorage("showParticles") private var showParticles: Bool = true
    @AppStorage("nearestParticleSensor") private var nearestParticleSensor: Bool = false

    @Environment(SurveyPresenter.self) private var electionPolls
    @AppStorage("enableElectionPolls") private var enableElectionPolls: Bool = false
    @AppStorage("showElectionPolls") private var showElectionPolls: Bool = true
    @AppStorage("electionPollScope") private var electionPollScope: Int = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("General")
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.bottom, 4)

            VStack(spacing: 12) {
                Toggle("Always Use Dark Theme", isOn: $enableDarkTheme)
                HStack {
                    Text("Override system theme settings.")
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
                        Text("Accent color in dark mode. Light mode uses the system color.")
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

        VStack(alignment: .leading, spacing: 8) {
            Text("Home")
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.bottom, 4)
            VStack(spacing: 12) {
                Toggle("Weather", isOn: $showWeather)
                HStack {
                    Text("Show weather conditions on the map.")
                        .font(.footnote)
                        .foregroundColor(.gray)
                    Spacer()
                }
                Toggle("COVID-19", isOn: $showCovid)
                HStack {
                    Text("Show COVID-19 incidence on the map.")
                        .font(.footnote)
                        .foregroundColor(.gray)
                    Spacer()
                }
                Toggle("Water", isOn: $showWater)
                HStack {
                    Text("Show water level on the map.")
                        .font(.footnote)
                        .foregroundColor(.gray)
                    Spacer()
                }
                Toggle("Radiation", isOn: $showRadiation)
                HStack {
                    Text("Show radiation on the map.")
                        .font(.footnote)
                        .foregroundColor(.gray)
                    Spacer()
                }
                Toggle("Particulate Matter", isOn: $showParticles)
                HStack {
                    Text("Show particulate matter on the map.")
                        .font(.footnote)
                        .foregroundColor(.gray)
                    Spacer()
                }
                if enableElectionPolls == true {
                    VStack {
                        Toggle("Election Polls", isOn: $showElectionPolls)
                        HStack {
                            Text("Show election polls on the map.")
                                .font(.footnote)
                                .foregroundColor(.gray)
                            Spacer()
                        }
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
        LocationSettingsView()

        PointOfInterestSettingsView(presenter: self.pointsOfInterest)

        VStack(alignment: .leading, spacing: 8) {
            Text("Water")
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.bottom, 4)
            VStack(spacing: 12) {
                Toggle("Nearest Sensor", isOn: $nearestLevelSensor)
                    .onChange(of: nearestLevelSensor) { _, _ in
                        AppProcess.shared.refreshSubscription(subscriber: level)
                    }
                HStack {
                    Text(
                        "Always select the nearest sensor, even if it is located at an artificial water body."
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Particulate Matter")
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.bottom, 4)
            VStack(spacing: 12) {
                Toggle("Nearest Sensor", isOn: $nearestParticleSensor)
                    .onChange(of: nearestParticleSensor) { _, _ in
                        AppProcess.shared.refreshSubscription(subscriber: particles)
                    }
                HStack {
                    Text(
                        "Always select the nearest sensor, even if it doesn't provide \u{1D40F}\u{1D40C}\u{2081}\u{2080}, \u{1D40F}\u{1D40C}\u{2082}\u{2085}, \u{1D40E}\u{2083} and \u{1D40D}\u{1D40E}\u{2082}."
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

        VStack(alignment: .leading, spacing: 8) {
            Text("Election Polls")
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.bottom, 4)
            VStack(spacing: 12) {
                Toggle("Enable", isOn: $enableElectionPolls)
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
                        Text("Show federal or state parliament election polls.")
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
}
