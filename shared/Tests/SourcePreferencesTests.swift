import DoomKitProcess
import Foundation
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
        #expect(SourcePreferences.sensorLimit(forKey: key, defaults: defaults) == ProcessSensor.maximumPerSource)
        defaults.set(false, forKey: key)
        #expect(SourcePreferences.sensorLimit(forKey: key, defaults: defaults) == 1)
    }

    @Test func eachSourceHasItsOwnSwitch() {
        let defaults = self.defaults()
        defaults.set(true, forKey: SourcePreferences.multiSensorParticlesKey)
        #expect(SourcePreferences.sensorLimit(forKey: SourcePreferences.multiSensorLevelKey, defaults: defaults) == 1)
        #expect(SourcePreferences.sensorLimit(forKey: SourcePreferences.multiSensorRadiationKey, defaults: defaults) == 1)
        #expect(SourcePreferences.sensorLimit(forKey: SourcePreferences.multiSensorParticlesKey, defaults: defaults) == ProcessSensor.maximumPerSource)
    }

    @Test func aLaunchArgumentStringTurnsTheSwitchOn() {
        // Launch arguments arrive as strings in the argument domain; bool(forKey:) reads them, which the UI test relies on.
        let defaults = self.defaults()
        defaults.set("YES", forKey: SourcePreferences.multiSensorLevelKey)
        #expect(SourcePreferences.sensorLimit(forKey: SourcePreferences.multiSensorLevelKey, defaults: defaults) == ProcessSensor.maximumPerSource)
    }
}
