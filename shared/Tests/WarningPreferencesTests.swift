import Foundation
import Testing

@Suite struct WarningPreferencesTests {
    private func defaults() -> UserDefaults {
        let suite = "WarningPreferencesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? UserDefaults.standard
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    private func rule(_ id: String) throws -> WarningRule {
        return try #require(WarningRule.catalogue.first { $0.id == id })
    }

    @Test func theKeysAreThePersistedNames() throws {
        // Stored in the user's defaults and passed as launch arguments, so a rename would silently reset the setting.
        #expect(WarningPreferences.enabledKey == "notificationsEnabled")
        #expect(WarningPreferences.stateKey == "warningState")
        #expect(WarningPreferences.familyKey(.level) == "notify.level")
        #expect(WarningPreferences.warningKey(try self.rule("radiation.total")) == "warning.radiation.total.warning")
        #expect(WarningPreferences.criticalKey(try self.rule("weather.frost")) == "warning.weather.frost.critical")
        #expect(WarningPreferences.hazardWarningKey == "warning.hazards.warning")
        #expect(WarningPreferences.hazardCriticalKey == "warning.hazards.critical")
    }

    @Test func ruleIdsAreUnique() {
        let ids = WarningRule.catalogue.map { $0.id }
        #expect(Set(ids).count == ids.count)
    }

    @Test func theDefaultsLieOnTheRightSideOfEachOther() {
        for rule in WarningRule.catalogue {
            #expect(rule.range.contains(rule.defaultWarning), "\(rule.id)")
            #expect(rule.range.contains(rule.defaultCritical), "\(rule.id)")
            switch rule.direction {
                case .above: #expect(rule.defaultCritical > rule.defaultWarning, "\(rule.id)")
                case .below: #expect(rule.defaultCritical < rule.defaultWarning, "\(rule.id)")
            }
        }
    }

    @Test func theMasterSwitchStartsOffAndEachFamilyHasItsOwnDefault() {
        let defaults = self.defaults()
        #expect(WarningPreferences.isEnabled(defaults: defaults) == false)
        #expect(WarningPreferences.isEnabled(.weather, defaults: defaults) == true)
        #expect(WarningPreferences.isEnabled(.level, defaults: defaults) == true)
        #expect(WarningPreferences.isEnabled(.hazards, defaults: defaults) == true)
        #expect(WarningPreferences.isEnabled(.covid, defaults: defaults) == false)
        #expect(WarningPreferences.isEnabled(.energy, defaults: defaults) == false)
        #expect(WarningPreferences.isEnabled(.fuel, defaults: defaults) == false)
        defaults.set(false, forKey: WarningPreferences.familyKey(.weather))
        #expect(WarningPreferences.isEnabled(.weather, defaults: defaults) == false)
    }

    @Test func unsetLimitsAreTheDefaults() throws {
        let rule = try self.rule("particle.pm10")
        #expect(WarningPreferences.limits(for: rule, defaults: self.defaults()) == WarningLimits(warning: 50, critical: 100))
    }

    @Test func launchArgumentStringsReachTheLimitsAndTheSwitches() throws {
        // Launch arguments arrive as strings, which double(forKey:) and bool(forKey:) parse.
        let defaults = self.defaults()
        let rule = try self.rule("radiation.total")
        defaults.set("0.01", forKey: WarningPreferences.warningKey(rule))
        defaults.set("YES", forKey: WarningPreferences.enabledKey)
        defaults.set("NO", forKey: WarningPreferences.familyKey(.level))
        #expect(WarningPreferences.limits(for: rule, defaults: defaults).warning == 0.01)
        #expect(WarningPreferences.isEnabled(defaults: defaults) == true)
        #expect(WarningPreferences.isEnabled(.level, defaults: defaults) == false)
    }

    @Test func aCriticalValueOnTheWrongSideActsAsTheWarningValue() throws {
        let defaults = self.defaults()
        let heat = try self.rule("weather.heat")
        defaults.set(40.0, forKey: WarningPreferences.warningKey(heat))
        defaults.set(35.0, forKey: WarningPreferences.criticalKey(heat))
        #expect(WarningPreferences.limits(for: heat, defaults: defaults) == WarningLimits(warning: 40, critical: 40))
        let frost = try self.rule("weather.frost")
        defaults.set(-5.0, forKey: WarningPreferences.warningKey(frost))
        defaults.set(0.0, forKey: WarningPreferences.criticalKey(frost))
        #expect(WarningPreferences.limits(for: frost, defaults: defaults) == WarningLimits(warning: -5, critical: -5))
    }

    @Test func limitsAreClampedToTheirRange() throws {
        let defaults = self.defaults()
        let rule = try self.rule("particle.o3")
        defaults.set(-10.0, forKey: WarningPreferences.warningKey(rule))
        defaults.set(99_999.0, forKey: WarningPreferences.criticalKey(rule))
        #expect(WarningPreferences.limits(for: rule, defaults: defaults) == WarningLimits(warning: 0, critical: 2000))
    }

    @Test func hazardSeveritiesDefaultAndOrder() {
        let defaults = self.defaults()
        #expect(WarningPreferences.hazardLimits(defaults: defaults) == (.moderate, .severe))
        defaults.set(Hazard.Severity.extreme.rawValue, forKey: WarningPreferences.hazardWarningKey)
        defaults.set(Hazard.Severity.minor.rawValue, forKey: WarningPreferences.hazardCriticalKey)
        #expect(WarningPreferences.hazardLimits(defaults: defaults) == (.extreme, .extreme))
        // Unknown is no bar to set.
        defaults.set(Hazard.Severity.unknown.rawValue, forKey: WarningPreferences.hazardWarningKey)
        #expect(WarningPreferences.hazardLimits(defaults: defaults).warning == .moderate)
    }
}
