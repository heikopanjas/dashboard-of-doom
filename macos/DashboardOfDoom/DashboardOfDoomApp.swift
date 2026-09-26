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

/// The dashboard's content with every presenter in its environment and the theme setting applied, hosted in the AppKit window.
private struct DashboardRootView: View {
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

    @ObservationIgnored private var dashboardWindow: NSWindow?
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

    // MARK: - Dashboard Window

    /// The dashboard window, built once and kept, so closing it keeps its tab and its frame. An AppKit window like the settings panel: a
    /// SwiftUI `Window` scene could only be opened with the `openWindow` action, which the app got from the menu bar extra it no longer has.
    private func makeDashboardWindow() -> NSWindow {
        let hostingController = NSHostingController(rootView: DashboardRootView(appDelegate: self))
        // The content's own minimum size, 700 by 720, becomes the window's.
        hostingController.sizingOptions = [.minSize]
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 859), styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false)
        window.title = "Dashboard of Doom"
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 800, height: 859))
        // Remembers where the user put it; the first time it opens centred.
        if window.setFrameUsingName("DashboardWindow") == false {
            window.center()
        }
        window.setFrameAutosaveName("DashboardWindow")
        return window
    }

    func showDashboard() -> Void {
        let window = self.dashboardWindow ?? self.makeDashboardWindow()
        self.dashboardWindow = window
        NSRunningApplication.current.activate(options: [.activateAllWindows])
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    func hideDashboard() -> Void {
        self.dashboardWindow?.close()
    }

    func toggleDashboard() -> Void {
        guard let window = self.dashboardWindow, window.isVisible == true else {
            self.showDashboard()
            return
        }
        // Visible but buried behind another app: raise it rather than hide it.
        if NSApp.isActive == true, window.isKeyWindow == true {
            self.hideDashboard()
        }
        else {
            self.showDashboard()
        }
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

            self.settingsPanel = panel

            NSApp.activate()
            panel.makeKeyAndOrderFront(nil)
            panel.orderFrontRegardless()
        }
    }
}
