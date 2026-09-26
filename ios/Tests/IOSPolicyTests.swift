import DoomKitLocation
import DoomKitProcess
import Foundation
import SwiftUI
import Testing

@MainActor
struct IOSPolicyTests {
    @Test func lifecycleStartsOnceAndRefreshesOnlyAfterBackground() {
        var starts = 0
        var refreshes = 0
        let lifecycle = AppActivityLifecycle(start: { starts += 1 }, refresh: { refreshes += 1 })
        lifecycle.start()
        lifecycle.start()
        lifecycle.becameActive()
        lifecycle.becameActive()
        #expect(starts == 1)
        #expect(refreshes == 0)
        lifecycle.enteredBackground()
        lifecycle.enteredBackground()
        lifecycle.becameActive()
        lifecycle.becameActive()
        #expect(starts == 1)
        #expect(refreshes == 1)
        lifecycle.enteredBackground()
        lifecycle.becameActive()
        #expect(refreshes == 2)
    }

    @Test func backgroundRefreshIsOnlyWantedWhileNotificationsAreOn() throws {
        let suite = "IOSPolicyTests.background.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(BackgroundRefresh.shouldSchedule(defaults: defaults) == false)
        defaults.set(true, forKey: WarningPreferences.enabledKey)
        #expect(BackgroundRefresh.shouldSchedule(defaults: defaults) == true)
    }

    @Test func theBackgroundTaskIdentifierIsTheOneInfoPlistPermits() throws {
        // The unhosted test bundle has no app Info.plist to read, so the plist file itself is the reference.
        let plist = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appending(path: "../DashboardOfDoom/Info.plist")
        let data = try Data(contentsOf: plist.standardizedFileURL)
        let info = try #require(try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        #expect((info["BGTaskSchedulerPermittedIdentifiers"] as? [String]) == [BackgroundRefresh.identifier])
        #expect((info["UIBackgroundModes"] as? [String])?.contains("fetch") == true)
    }

    @Test func accentSelectionSurvivesRelaunch() throws {
        let suite = "IOSPolicyTests.accent.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let original = ColorPresenter(defaults: defaults)
        original.selectAccent("blue")
        let relaunched = ColorPresenter(defaults: defaults)
        #expect(relaunched.tint(for: .dark) == original.tint(for: .dark))
        #expect(defaults.string(forKey: ColorPresenter.storageKey) == "blue")
    }

    @Test func lightModeUsesSystemTintAndKeepsSelection() throws {
        let suite = "IOSPolicyTests.accent.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let presenter = ColorPresenter(defaults: defaults)
        presenter.selectAccent("orange")
        #expect(presenter.tint(for: .light) == nil)
        #expect(presenter.tint(for: .dark) == Color.orange)
        #expect(presenter.selectedAccent.id == "orange")
        #expect(defaults.string(forKey: ColorPresenter.storageKey) == "orange")
    }

    @Test func unknownAccentIsIgnoredAndNeverPersisted() throws {
        let suite = "IOSPolicyTests.accent.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let presenter = ColorPresenter(defaults: defaults)
        #expect(presenter.selectedAccent == ColorPresenter.defaultAccent)
        #expect(defaults.string(forKey: ColorPresenter.storageKey) == nil)
        presenter.selectAccent("chartreuse")
        #expect(presenter.selectedAccent == ColorPresenter.defaultAccent)
        #expect(defaults.string(forKey: ColorPresenter.storageKey) == nil)
    }

    @Test(arguments: [
        ("purple", "blue"), ("indigo", "blue"), ("red", "orange"), ("mint", "cyan"), ("black", "cyan"),
    ])
    func retiredAccentMigratesOnLaunch(stored: String, expected: String) throws {
        let suite = "IOSPolicyTests.accent.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(stored, forKey: ColorPresenter.storageKey)
        let presenter = ColorPresenter(defaults: defaults)
        #expect(presenter.selectedAccent.id == expected)
        #expect(defaults.string(forKey: ColorPresenter.storageKey) == expected)
    }

    @Test func accentCatalogIsExactlyThreeInDisplayOrder() {
        #expect(ColorPresenter.accents.map(\.id) == ["orange", "cyan", "blue"])
    }

    @Test func legacyKeysAndPollVisibilityRemainIndependent() throws {
        let suite = "IOSPolicyTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(SourcePreferences.waterKey == "showWater")
        #expect(SourcePreferences.pollsEnableKey == "enableElectionPolls")
        #expect(SourcePreferences.pollsEnabledByDefault == false)
        #expect(SourcePreferences.pollsVisible(defaults: defaults) == false)
        // COVID is the same shape: its own enable key on iOS, off until switched on, and the map label needs both keys.
        #expect(SourcePreferences.covidEnableKey == "enableCovid")
        #expect(SourcePreferences.covidEnabledByDefault == false)
        #expect(SourcePreferences.covidVisible(defaults: defaults) == false)
        defaults.set(true, forKey: SourcePreferences.covidEnableKey)
        #expect(SourcePreferences.covidVisible(defaults: defaults) == true)
        defaults.set(false, forKey: "showCovid")
        #expect(SourcePreferences.covidVisible(defaults: defaults) == false)
        // Energy is on by default and has one key, since it has nothing on the map.
        #expect(SourcePreferences.energyEnableKey == "enableEnergy")
        #expect(SourcePreferences.energyEnabledByDefault == true)
        var registrations = 0
        var removals = 0
        let presenter = SurveyPresenter(
            defaults: defaults, register: { _, _ in registrations += 1 }, remove: { _ in removals += 1 }, fetch: { _ in [] })
        #expect(registrations == 0)
        defaults.set(true, forKey: "enableElectionPolls")
        NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: defaults)
        #expect(registrations == 1)
        #expect(SourcePreferences.pollsVisible(defaults: defaults) == true)
        defaults.set(false, forKey: "showElectionPolls")
        NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: defaults)
        #expect(registrations == 1)
        #expect(removals == 0)
        #expect(SourcePreferences.pollsVisible(defaults: defaults) == false)
        defaults.set(false, forKey: "enableElectionPolls")
        NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: defaults)
        #expect(removals == 1)
        withExtendedLifetime(presenter) {}
    }
}
