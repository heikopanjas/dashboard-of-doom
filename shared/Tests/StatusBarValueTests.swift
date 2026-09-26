import DoomKitProcess
import Foundation
import Testing

@Suite struct StatusBarValueTests {
    private func defaults() -> UserDefaults {
        let suite = "StatusBarValueTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? UserDefaults.standard
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test func theKeyIsThePersistedName() {
        #expect(StatusBarPreferences.valuesKey == "statusBar.values")
    }

    @Test func nothingTickedShowsTheTemperature() {
        let defaults = self.defaults()
        #expect(StatusBarPreferences.selection(defaults: defaults).isEmpty)
        #expect(StatusBarPreferences.displayed(defaults: defaults) == [.temperature])
    }

    @Test func atMostTwoInTheOrderTheyWereTicked() {
        let defaults = self.defaults()
        StatusBarPreferences.toggle(.pm10, defaults: defaults)
        StatusBarPreferences.toggle(.temperature, defaults: defaults)
        StatusBarPreferences.toggle(.radiation, defaults: defaults)
        #expect(StatusBarPreferences.selection(defaults: defaults) == [.pm10, .temperature])
        // At the limit only the ticked ones can change.
        #expect(StatusBarPreferences.canSelect(.radiation, defaults: defaults) == false)
        #expect(StatusBarPreferences.canSelect(.pm10, defaults: defaults) == true)
        StatusBarPreferences.toggle(.pm10, defaults: defaults)
        #expect(StatusBarPreferences.selection(defaults: defaults) == [.temperature])
        #expect(StatusBarPreferences.canSelect(.radiation, defaults: defaults) == true)
    }

    @Test func aValueWhoseSourceIsOffIsLeftOut() {
        let defaults = self.defaults()
        StatusBarPreferences.setSelection([.pm10, .waterLevel], defaults: defaults)
        defaults.set(false, forKey: SourcePreferences.particlesKey)
        #expect(StatusBarPreferences.displayed(defaults: defaults) == [.waterLevel])
        defaults.set(false, forKey: SourcePreferences.waterKey)
        #expect(StatusBarPreferences.displayed(defaults: defaults) == [.temperature])
        // The selection itself is kept for when the source comes back.
        #expect(StatusBarPreferences.selection(defaults: defaults) == [.pm10, .waterLevel])
    }

    @Test func unknownAndRepeatedStoredValuesAreSkipped() {
        let defaults = self.defaults()
        defaults.set(["futureValue", "pm25", "pm25", "brent", "wti"], forKey: StatusBarPreferences.valuesKey)
        #expect(StatusBarPreferences.selection(defaults: defaults) == [.pm25, .brent])
    }

    @Test func everyValueBelongsToOneSourceAndReadsItsSeries() {
        for value in StatusBarValue.allCases {
            #expect(StatusBarValue.values(of: value.source).contains(value))
            #expect(value.label.isEmpty == false)
        }
        #expect(StatusBarValue.temperature.selector == .weather(.temperature))
        #expect(StatusBarValue.waterLevel.selector == .water(.level))
        #expect(StatusBarValue.lng.selector == .energy(.lng))
        #expect(Set(StatusBarValue.Source.allCases.map { $0.symbol }).count == StatusBarValue.Source.allCases.count)
    }
}
