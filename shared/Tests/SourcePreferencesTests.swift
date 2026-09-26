import DoomKitProcess
import Foundation
import SwiftUI
import Testing

@Suite struct SourcePreferencesTests {
    private static let keys = [
        SourcePreferences.multiSensorLevelKey, SourcePreferences.multiSensorRadiationKey, SourcePreferences.multiSensorParticlesKey
    ]

    private func defaults() -> UserDefaults {
        let suite = "SourcePreferencesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? UserDefaults.standard
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test func theKeysAreThePersistedNames() {
        // Stored in the user's defaults and passed as launch arguments, so a rename would silently reset the setting.
        #expect(Self.keys == ["multiSensorLevel", "multiSensorRadiation", "multiSensorParticles"])
        #expect(SourcePreferences.multiSensorLevelOtherWaterwaysKey == "multiSensorLevelOtherWaterways")
    }

    @Test(arguments: [
        SourcePreferences.multiSensorLevelKey, SourcePreferences.multiSensorRadiationKey, SourcePreferences.multiSensorParticlesKey
    ])
    func aSourceFetchesOneSensorUnlessItsSwitchIsOn(key: String) {
        let defaults = self.defaults()
        // Unset is off, which is what the setting defaults to.
        #expect(SourcePreferences.sensorLimit(forKey: key, defaults: defaults) == 1)
        defaults.set(false, forKey: key)
        #expect(SourcePreferences.sensorLimit(forKey: key, defaults: defaults) == 1)
        defaults.set(true, forKey: key)
        #expect(SourcePreferences.sensorLimit(forKey: key, defaults: defaults) == SourcePreferences.sensorMaximum(forKey: key))
        defaults.set(false, forKey: key)
        #expect(SourcePreferences.sensorLimit(forKey: key, defaults: defaults) == 1)
    }

    @Test func eachSourceHasItsOwnSwitch() {
        let defaults = self.defaults()
        defaults.set(true, forKey: SourcePreferences.multiSensorParticlesKey)
        #expect(SourcePreferences.sensorLimit(forKey: SourcePreferences.multiSensorLevelKey, defaults: defaults) == 1)
        #expect(SourcePreferences.sensorLimit(forKey: SourcePreferences.multiSensorRadiationKey, defaults: defaults) == 1)
        #expect(
            SourcePreferences.sensorLimit(forKey: SourcePreferences.multiSensorParticlesKey, defaults: defaults)
                == SourcePreferences.sensorMaximum(forKey: SourcePreferences.multiSensorParticlesKey))
    }

    @Test func eachPlatformHasItsOwnCaps() {
        #expect(SourcePreferences.sensorMaximum(forKey: "somethingElse") == ProcessSensor.maximumPerSource)
        #if os(iOS)
        // Level and radiation share the Environment map, three each; the Particles tab is its own tab with its own six colors.
        #expect(SourcePreferences.sensorMaximum(forKey: SourcePreferences.multiSensorLevelKey) == 3)
        #expect(SourcePreferences.sensorMaximum(forKey: SourcePreferences.multiSensorRadiationKey) == 3)
        #expect(SourcePreferences.sensorMaximum(forKey: SourcePreferences.multiSensorParticlesKey) == 6)
        // One color per station, so the palette and the cap must not drift apart.
        #expect(SourcePreferences.particlesSensorMaximum == Color.particleSensors.count)
        #else
        // Each source has a tab and a map of its own on macOS, so each takes all six label colors.
        for key in [SourcePreferences.multiSensorLevelKey, SourcePreferences.multiSensorRadiationKey, SourcePreferences.multiSensorParticlesKey] {
            #expect(SourcePreferences.sensorMaximum(forKey: key) == 6)
        }
        #expect(SourcePreferences.macOSSensorMaximum == Color.waterTabSensors.count)
        #expect(SourcePreferences.macOSSensorMaximum == Color.radiationTabSensors.count)
        #endif
    }

    @Test func aSwitchReadsUnsetAsItsDefaultAndAcceptsLaunchArgumentStrings() {
        let defaults = self.defaults()
        #expect(SourcePreferences.enabled(key: "switch", default: true, defaults: defaults) == true)
        #expect(SourcePreferences.enabled(key: "switch", default: false, defaults: defaults) == false)
        defaults.set(false, forKey: "switch")
        #expect(SourcePreferences.enabled(key: "switch", default: true, defaults: defaults) == false)
        // A launch argument such as -enableCovid YES arrives as a string, which `as? Bool` would have ignored.
        defaults.set("YES", forKey: "switch")
        #expect(SourcePreferences.enabled(key: "switch", default: false, defaults: defaults) == true)
        defaults.set("NO", forKey: "switch")
        #expect(SourcePreferences.enabled(key: "switch", default: true, defaults: defaults) == false)
    }

    @Test func everySourceIsVisibleExactlyWhileItsOneSwitchIsOn() {
        let defaults = self.defaults()
        let sources: [(String, (UserDefaults) -> Bool)] = [
            (SourcePreferences.covidEnableKey, { SourcePreferences.covidVisible(defaults: $0) }),
            (SourcePreferences.waterKey, { SourcePreferences.waterVisible(defaults: $0) }),
            (SourcePreferences.radiationKey, { SourcePreferences.radiationVisible(defaults: $0) }),
            (SourcePreferences.particlesKey, { SourcePreferences.particlesVisible(defaults: $0) }),
            (SourcePreferences.hazardsKey, { SourcePreferences.hazardsVisible(defaults: $0) }),
            (SourcePreferences.energyEnableKey, { SourcePreferences.energyVisible(defaults: $0) }),
            (SourcePreferences.pollsEnableKey, { SourcePreferences.pollsVisible(defaults: $0) }),
        ]
        #expect(Set(sources.map { $0.0 }) == Set(SourcePreferences.switchKeys))
        for (key, visible) in sources {
            defaults.set(true, forKey: key)
            #expect(visible(defaults) == true, "\(key)")
            defaults.set(false, forKey: key)
            #expect(visible(defaults) == false, "\(key)")
        }
    }

    @Test func theSwitchKeysAreThePersistedNames() {
        #expect(SourcePreferences.radiationKey == "showRadiation")
        #expect(SourcePreferences.particlesKey == "showParticles")
        #expect(SourcePreferences.hazardsKey == "showHazards")
        #if os(macOS)
        #expect(SourcePreferences.waterKey == "showLevels")
        #expect(SourcePreferences.covidEnableKey == "showCovid")
        #expect(SourcePreferences.pollsEnableKey == "showElectionPolls")
        #endif
    }

    @Test func theHistoricalSensorKeysStay() {
        // The settings now say Any Waterway and Any Station, but the stored names stay so nobody's choice resets.
        #expect(SourcePreferences.nearestLevelSensorKey == "nearestLevelSensor")
        #expect(SourcePreferences.nearestParticleSensorKey == "nearestParticleSensor")
    }

    @Test(arguments: SourcePreferences.LevelWaterways.allCases)
    func aWaterwayChoiceSurvivesTheRoundTripThroughItsSwitches(choice: SourcePreferences.LevelWaterways) {
        let switches = choice.switches
        #expect(SourcePreferences.LevelWaterways(nearest: switches.nearest, otherWaterways: switches.otherWaterways, multiSensor: true) == choice)
    }

    @Test func theStoredSwitchesMapToOneChoice() {
        typealias Choice = SourcePreferences.LevelWaterways
        #expect(Choice(nearest: false, otherWaterways: false, multiSensor: true) == .natural)
        #expect(Choice(nearest: false, otherWaterways: true, multiSensor: true) == .naturalFirst)
        // Any waterway ties nothing to one waterway, so it wins over the extra gauges' switch.
        #expect(Choice(nearest: true, otherWaterways: true, multiSensor: true) == .any)
        // Without extra gauges Natural First changes nothing, so it shows as Natural and is not offered.
        #expect(Choice(nearest: false, otherWaterways: true, multiSensor: false) == .natural)
        #expect(Choice.choices(multiSensor: false) == [.natural, .any])
        #expect(Choice.choices(multiSensor: true) == [.natural, .naturalFirst, .any])
    }

    @Test func aLaunchArgumentStringTurnsTheSwitchOn() {
        // Launch arguments arrive as strings in the argument domain; bool(forKey:) reads them, which the UI test relies on.
        let defaults = self.defaults()
        defaults.set("YES", forKey: SourcePreferences.multiSensorLevelKey)
        #expect(
            SourcePreferences.sensorLimit(forKey: SourcePreferences.multiSensorLevelKey, defaults: defaults)
                == SourcePreferences.sensorMaximum(forKey: SourcePreferences.multiSensorLevelKey))
    }
}
