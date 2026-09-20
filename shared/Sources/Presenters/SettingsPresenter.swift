import SwiftUI

class SettingsPresenter {
    @AppStorage("showWeather") var showWeather: Bool = true
    @AppStorage("showCovid") var showCovid: Bool = true
    @AppStorage("showLevels") var showLevels: Bool = true
    @AppStorage("showRadiation") var showRadiation: Bool = true
    @AppStorage("showParticles") var showParticles: Bool = true
    @AppStorage("showElectionPolls") var showElectionPolls: Bool = true

    @AppStorage("nearestLevelSensor") var nearestLevelSensor: Bool = false
    @AppStorage("nearestParticleSensor") var nearestParticleSensor: Bool = false
    @AppStorage("electionPollScope") var electionPollScope: Int = 1
}
