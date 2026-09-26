import DoomKitLocation
import DoomKitProcess
import Foundation
import Testing

/// The home map's camera fits the nearest sensor of every source that is switched on. A switch that was never touched is on, as it is in
/// Settings and for refreshing; reading it with `bool(forKey:)` once dropped level, radiation and particles from the camera while their
/// labels still showed, so the labels sat at the edges of a map zoomed to the weather and COVID dots.
@MainActor
@Suite struct HomeMapRegionTests {
    private static let gauge = Location(latitude: 52.5149, longitude: 13.4087)

    private func sensors() -> [ProcessSensor] {
        return [ProcessSensor(name: "Sensor", location: Self.gauge, measurements: [:], timestamp: .now)]
    }

    private func defaults() -> (UserDefaults, String) {
        let suite = "HomeMapRegionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defaults.removePersistentDomain(forName: suite)
        return (defaults, suite)
    }

    private func check(_ presenter: ProcessPresenter & ProcessRefreshable, defaults: UserDefaults, key: String) async {
        // Never touched: on, so the sensor joins the camera.
        await presenter.refreshData(location: Self.gauge)
        #expect(MapPresenter.shared.visibleRegion[presenter.id] == Self.gauge)
        MapPresenter.shared.updateRegion(remove: presenter.id)
        // Switched on explicitly: the same.
        defaults.set(true, forKey: key)
        await presenter.refreshData(location: Self.gauge)
        #expect(MapPresenter.shared.visibleRegion[presenter.id] == Self.gauge)
        MapPresenter.shared.updateRegion(remove: presenter.id)
    }

    @Test func anUntouchedLevelSwitchKeepsTheGaugeInTheCamera() async {
        let (defaults, suite) = self.defaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let presenter = LevelPresenter(defaults: defaults, register: { _, _ in }, remove: { _ in }, fetch: { _ in self.sensors() })
        await self.check(presenter, defaults: defaults, key: SourcePreferences.waterKey)
    }

    @Test func anUntouchedRadiationSwitchKeepsTheStationInTheCamera() async {
        let (defaults, suite) = self.defaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let presenter = RadiationPresenter(defaults: defaults, register: { _, _ in }, remove: { _ in }, fetch: { _ in self.sensors() })
        await self.check(presenter, defaults: defaults, key: "showRadiation")
    }

    @Test func anUntouchedParticleSwitchKeepsTheStationInTheCamera() async {
        let (defaults, suite) = self.defaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let presenter = ParticlePresenter(defaults: defaults, register: { _, _ in }, remove: { _ in }, fetch: { _ in self.sensors() })
        await self.check(presenter, defaults: defaults, key: "showParticles")
    }
}
