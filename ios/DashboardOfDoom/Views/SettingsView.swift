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
    @AppStorage("showHazards") private var showHazards: Bool = true

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
                Toggle("COVID-19", isOn: $showCovid)
                HStack {
                    Text("Shows incidence on the map. Turning it off also stops COVID-19 from updating.")
                        .font(.footnote)
                        .foregroundColor(.gray)
                    Spacer()
                }
                Toggle("Water", isOn: $showWater)
                HStack {
                    Text("Shows the water level on the map. Turning it off also stops it from updating.")
                        .font(.footnote)
                        .foregroundColor(.gray)
                    Spacer()
                }
                Toggle("Radiation", isOn: $showRadiation)
                HStack {
                    Text("Shows the dose rate on the map. Turning it off also stops it from updating.")
                        .font(.footnote)
                        .foregroundColor(.gray)
                    Spacer()
                }
                Toggle("Particulate Matter", isOn: $showParticles)
                HStack {
                    Text("Shows particulates on the map. Turning it off also stops them from updating.")
                        .font(.footnote)
                        .foregroundColor(.gray)
                    Spacer()
                }
                Toggle("Warnings", isOn: $showHazards)
                HStack {
                    Text("Shows civil protection and weather warnings near you on the Home screen. Turning it off also stops them from updating.")
                        .font(.footnote)
                        .foregroundColor(.gray)
                    Spacer()
                }
                if enableElectionPolls == true {
                    VStack {
                        Toggle("Election Polls", isOn: $showElectionPolls)
                        HStack {
                            Text("Shows poll results on the map. The Polls tab keeps them either way.")
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Points of Interest")
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.bottom, 4)
            PointOfInterestSettingsView(presenter: self.pointsOfInterest)
        }

        LocationSettingsView()

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
                        "Use the closest gauge, even on a canal. Otherwise a gauge on the nearest river or stream is preferred."
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
                        "Use the closest station, even if it measures only some pollutants. Otherwise a station reporting \u{1D40F}\u{1D40C}\u{2081}\u{2080}, \u{1D40F}\u{1D40C}\u{2082}\u{2085}, \u{1D40E}\u{2083} and \u{1D40D}\u{1D40E}\u{2082} is preferred."
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
                HStack {
                    Text("Downloads polling data and adds the Polls tab.")
                        .font(.footnote)
                        .foregroundColor(.gray)
                    Spacer()
                }
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
}
