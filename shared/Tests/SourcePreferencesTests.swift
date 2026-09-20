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

    @Test func particlesReportMoreStationsThanTheOtherSources() {
        // The Particles tab is its own tab with its own six colors, so it shows six where the Environment tab's sources show three.
        #expect(SourcePreferences.sensorMaximum(forKey: SourcePreferences.multiSensorLevelKey) == ProcessSensor.maximumPerSource)
        #expect(SourcePreferences.sensorMaximum(forKey: SourcePreferences.multiSensorRadiationKey) == ProcessSensor.maximumPerSource)
        #expect(SourcePreferences.sensorMaximum(forKey: "somethingElse") == ProcessSensor.maximumPerSource)
        #if os(iOS)
        #expect(SourcePreferences.sensorMaximum(forKey: SourcePreferences.multiSensorParticlesKey) == 6)
        // One color per station, so the palette and the cap must not drift apart.
        #expect(SourcePreferences.particlesSensorMaximum == Color.particleSensors.count)
        #else
        // macOS shows only the nearest, so fetching more would download data nobody sees.
        #expect(SourcePreferences.sensorMaximum(forKey: SourcePreferences.multiSensorParticlesKey) == 1)
        #endif
    }

    @Test func aLaunchArgumentStringTurnsTheSwitchOn() {
        // Launch arguments arrive as strings in the argument domain; bool(forKey:) reads them, which the UI test relies on.
        let defaults = self.defaults()
        defaults.set("YES", forKey: SourcePreferences.multiSensorLevelKey)
        #expect(SourcePreferences.sensorLimit(forKey: SourcePreferences.multiSensorLevelKey, defaults: defaults) == ProcessSensor.maximumPerSource)
    }
}
