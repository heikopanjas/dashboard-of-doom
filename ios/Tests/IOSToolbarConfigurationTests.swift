import Foundation
import Testing

struct IOSToolbarConfigurationTests {
    @Test func theDefaultToolbarHasSevenButtonsInTheRequestedOrder() {
        let configuration = IOSToolbarConfiguration()
        #expect(
            [IOSScreen.home, .weather] + configuration.screens + [.settings] == [
                .home, .weather, .level, .radiation, .particles, .covid, .settings
            ])
    }

    @Test(arguments: [
        "", "broken", "null", "[]", "[\"level\"]", "[\"level\",\"radiation\",\"particles\",\"home\"]",
        "[\"level\",\"level\",\"particles\",\"covid\"]", "[\"level\",\"environment\",\"particles\",\"covid\"]",
        "[\"level\",\"radiation\",\"particles\",\"covid\",\"energy\"]"
    ])
    func invalidStorageRestoresTheDefault(value: String) {
        #expect(IOSToolbarConfiguration(storedValue: value).screens == IOSToolbarConfiguration.defaultScreens)
    }

    @Test func assignmentsSurviveAStorageRoundTrip() throws {
        let suite = "IOSToolbarConfigurationTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var configuration = IOSToolbarConfiguration()
        _ = configuration.assign(.energy, to: 0, selected: .home, enabled: true)
        _ = configuration.assign(.surveys, to: 3, selected: .energy, enabled: true)
        defaults.set(configuration.storedValue, forKey: IOSToolbarConfiguration.storageKey)
        let restored = IOSToolbarConfiguration(storedValue: defaults.string(forKey: IOSToolbarConfiguration.storageKey) ?? "")
        #expect(restored.screens == [.energy, .radiation, .particles, .surveys])
    }

    @Test(arguments: IOSScreen.customizable, 0 ..< 4)
    func everyAssignmentKeepsFourDistinctSourcesAndOpensTheChoice(screen: IOSScreen, slot: Int) {
        var configuration = IOSToolbarConfiguration()
        let previous = configuration.screens[slot]
        let previousSlot = configuration.screens.firstIndex(of: screen)
        let selected = configuration.assign(screen, to: slot, selected: .home, enabled: true)
        #expect(selected == screen)
        #expect(configuration.screens.count == 4)
        #expect(Set(configuration.screens).count == 4)
        #expect(configuration.screens[slot] == screen)
        if let previousSlot = previousSlot {
            #expect(configuration.screens[previousSlot] == previous)
        }
    }

    @Test func assigningTheSameScreenKeepsTheOrder() {
        var configuration = IOSToolbarConfiguration()
        let selected = configuration.assign(.level, to: 0, selected: .home, enabled: true)
        #expect(configuration.screens == IOSToolbarConfiguration.defaultScreens)
        #expect(selected == .level)
    }

    @Test(arguments: [IOSScreen.home, .weather, .settings, .radiation, .particles, .covid])
    func aDisabledReplacementKeepsAScreenThatIsStillAvailable(selected: IOSScreen) {
        var configuration = IOSToolbarConfiguration()
        #expect(configuration.assign(.energy, to: 0, selected: selected, enabled: false) == selected)
        #expect(configuration.screens[0] == .energy)
    }

    @Test func replacingTheOpenScreenWithADisabledSourceReturnsHome() {
        var configuration = IOSToolbarConfiguration()
        #expect(configuration.assign(.energy, to: 0, selected: .level, enabled: false) == .home)
    }

    @Test func swappingADisabledSourceKeepsTheOpenScreenInItsNewPosition() {
        var configuration = IOSToolbarConfiguration()
        #expect(configuration.assign(.covid, to: 0, selected: .level, enabled: false) == .level)
        #expect(configuration.screens == [.covid, .radiation, .particles, .level])
    }

    @Test(arguments: [IOSScreen.home, .weather, .settings])
    func fixedScreensCannotBeAssigned(screen: IOSScreen) {
        var configuration = IOSToolbarConfiguration()
        #expect(configuration.assign(screen, to: 0, selected: .particles, enabled: true) == .particles)
        #expect(configuration.screens == IOSToolbarConfiguration.defaultScreens)
    }

    @Test(arguments: [-1, 4])
    func invalidPositionsCannotChangeTheToolbar(slot: Int) {
        var configuration = IOSToolbarConfiguration()
        #expect(configuration.assign(.energy, to: slot, selected: .home, enabled: true) == .home)
        #expect(configuration.screens == IOSToolbarConfiguration.defaultScreens)
    }
}
