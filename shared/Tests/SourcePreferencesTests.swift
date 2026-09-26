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
