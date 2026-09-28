import DoomKitProcess
import DoomKitNetwork
import AppKit
import KeyboardShortcuts
import SwiftUI

@main
struct DashboardOfDoomApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // The status item and the dashboard window are AppKit, owned by AppDelegate, so SwiftUI only needs a scene to exist: an empty
    // Settings scene, since the app's own settings are a panel as well.
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

// MARK: - Dashboard

/// The dashboard's content with every presenter in its environment and the theme setting applied, hosted in the status item's popup.
struct DashboardRootView: View {
    let appDelegate: AppDelegate
    @AppStorage("alwaysUseDarkTheme") private var alwaysUseDarkTheme: Bool = true

    var body: some View {
        ContentView()
            .environment(self.appDelegate.weatherPresenter)
            .environment(self.appDelegate.forecastPresenter)
            .environment(self.appDelegate.covidPresenter)
            .environment(self.appDelegate.levelPresenter)
            .environment(self.appDelegate.radiationPresenter)
            .environment(self.appDelegate.particlePresenter)
            .environment(self.appDelegate.surveyPresenter)
            .environment(self.appDelegate.hazardPresenter)
            .environment(self.appDelegate.energyPresenter)
            .environment(self.appDelegate.fuelPresenter)
            .environment(self.appDelegate.colorPresenter)
            .environment(self.appDelegate)
            .environment(self.appDelegate.pointOfInterestPresenter)
            .preferredColorScheme(self.alwaysUseDarkTheme ? .dark : nil)
    }
}

// MARK: - App Delegate

@MainActor @Observable
class AppDelegate: NSObject, NSApplicationDelegate {
    let weatherPresenter = WeatherPresenter()
    let forecastPresenter = ForecastPresenter()
    let covidPresenter = CovidPresenter()
    let levelPresenter = LevelPresenter()
    let radiationPresenter = RadiationPresenter()
    let particlePresenter = ParticlePresenter()
    let surveyPresenter = SurveyPresenter()
    let hazardPresenter = HazardPresenter()
    let energyPresenter = EnergyPresenter()
    let fuelPresenter = FuelPresenter()
    let colorPresenter = ColorPresenter()
    // Every category keeps loading whatever the map shows, for the nearest places row on the Home tab, as on iOS.
    let pointOfInterestPresenter = PointOfInterestPresenter(fetch: { category, location in
        return try await PointOfInterestController().fetch(category: category, location: location)
    }, fetchesWhenHidden: true)

    let settingsSelection = SettingsSelection()
    var settingsPanel: NSPanel?
    var simulationWindow: NSWindow?

    @ObservationIgnored private var statusItemController: StatusItemController?
    @ObservationIgnored private var themeObserver: NSObjectProtocol?
    @ObservationIgnored private var shutdownTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        AppSecrets.runSelfCheckIfRequested()
        #endif
        // Before anything can post, so notices show while the app is in front.
        NotificationCenterPoster.shared.activate()
        AppProcess.shared.start()
        self.pointOfInterestPresenter.start(updates: AppLocation.shared.updates())
        self.statusItemController = StatusItemController(appDelegate: self)

        // Apply initial theme
        updateAppearance()

        // Observe theme setting changes
        themeObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateAppearance() }
        }

        // System-wide toggle for the dashboard window
        KeyboardShortcuts.onKeyUp(for: .toggleDashboard) { [weak self] in
            self?.toggleDashboard()
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        self.pointOfInterestPresenter.stop()
        AppProcess.shared.stop()
        self.shutdownTask?.cancel()
        self.shutdownTask = Task {
            await NetworkManager.shared.stopMonitoring()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    isolated deinit {
        self.shutdownTask?.cancel()
    }

    func updateAppearance() {
        let alwaysUseDarkTheme = UserDefaults.standard.bool(forKey: "alwaysUseDarkTheme")
        // Default to true if key doesn't exist (first launch)
        let useDark = UserDefaults.standard.object(forKey: "alwaysUseDarkTheme") == nil ? true : alwaysUseDarkTheme
        NSApp.appearance = useDark ? NSAppearance(named: .darkAqua) : nil
    }

    /// The nearest reading's faceplate for a status bar value, the string the map labels show. The status item and its settings both read
    /// it here, so they always show the same text.
    func faceplate(for value: StatusBarValue) -> String? {
        let presenter: ProcessPresenter
        switch value.source {
            case .weather: presenter = self.weatherPresenter
            case .covid: presenter = self.covidPresenter
            case .water: presenter = self.levelPresenter
            case .radiation: presenter = self.radiationPresenter
            case .particles: presenter = self.particlePresenter
            case .energy: presenter = self.energyPresenter
        }
        return presenter.faceplate[value.selector]
    }

    // MARK: - Dashboard

    /// The global shortcut opens and closes the dashboard popup under the status item, the same popup a click opens.
    func toggleDashboard() -> Void {
        self.statusItemController?.togglePopover()
    }

    // MARK: - Simulation Window

    /// The window to pick a place to simulate, from the status item's menu. Built fresh each time, centred on where the app is now, so an
    /// earlier pick does not linger; Start simulates the pick and closes it.
    func showSimulation() {
        if let window = self.simulationWindow, window.isVisible == true {
            NSApp.activate()
            window.makeKeyAndOrderFront(nil)
            return
        }
        let view = SimulationView(start: AppLocation.shared.state.location) { [weak self] location, _ in
            AppLocation.shared.simulate(location)
            self?.simulationWindow?.close()
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 600), styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered, defer: false)
        window.title = "Simulation"
        window.contentViewController = NSHostingController(rootView: view)
        window.setContentSize(NSSize(width: 640, height: 600))
        window.isReleasedWhenClosed = false
        window.center()
        self.simulationWindow = window
        // The app has no Dock icon and is never active on its own, so it activates first for the window to take the keyboard.
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    // MARK: - Settings Window

    func showSettings(tab: SettingsTab? = nil) {
        if let tab {
            self.settingsSelection.tab = tab
        }

        DispatchQueue.main.async {
            // Force activate the app first using NSRunningApplication
            NSRunningApplication.current.activate(options: [.activateAllWindows])

            if let panel = self.settingsPanel {
                // Panel already exists, just show it
                panel.makeKeyAndOrderFront(nil)
                panel.orderFrontRegardless()
                NSApp.activate()
                return
            }

            // Create new settings panel
            let settingsView = SettingsView(
                selection: self.settingsSelection,
                levelPresenter: self.levelPresenter,
                radiationPresenter: self.radiationPresenter,
                particlePresenter: self.particlePresenter,
                surveyPresenter: self.surveyPresenter,
                covidPresenter: self.covidPresenter,
                energyPresenter: self.energyPresenter,
                fuelPresenter: self.fuelPresenter,
                pointOfInterestPresenter: self.pointOfInterestPresenter,
                faceplate: { [unowned self] value in self.faceplate(for: value) }
            )
            let hostingController = NSHostingController(rootView: settingsView)
            hostingController.view.frame = NSRect(x: 0, y: 0, width: SettingsView.width, height: 400)

            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: SettingsView.width, height: 400),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )

            panel.title = "Settings"
            panel.contentViewController = hostingController
            panel.center()
            panel.isReleasedWhenClosed = false
            // A panel hides while its app is inactive, and the activation above is only a request: opened from a menu bar manager's hidden
            // section, the app can stay inactive, and the panel would never appear.
            panel.hidesOnDeactivate = false

            self.settingsPanel = panel

            NSApp.activate()
            panel.makeKeyAndOrderFront(nil)
            panel.orderFrontRegardless()
        }
    }
}
