import DoomKitProcess
import DoomKitNetwork
import AppKit
import KeyboardShortcuts
import SwiftUI

@main
struct DashboardOfDoomApp: App {
    @AppStorage("alwaysUseDarkTheme") private var alwaysUseDarkTheme: Bool = true

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(appDelegate: self.appDelegate)
        } label: {
            MenuBarLabelView(appDelegate: self.appDelegate, weatherPresenter: self.appDelegate.weatherPresenter)
        }
        .menuBarExtraStyle(.menu)

        Window("Dashboard of Doom", id: AppDelegate.dashboardWindowID) {
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
                .background(DashboardWindowAccessor { [appDelegate] window in
                    appDelegate.registerDashboardWindow(window)
                })
        }
        .defaultSize(width: 800, height: 859)
        .defaultPosition(.center)
        .windowResizability(.contentMinSize)
        .defaultLaunchBehavior(.suppressed)
    }
}

// MARK: - Menu Bar Views

private struct MenuBarLabelView: View {
    let appDelegate: AppDelegate
    let weatherPresenter: WeatherPresenter

    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        Text(self.weatherPresenter.faceplate[.weather(.temperature)] ?? "n/a")
            .font(.system(.body, design: .monospaced))
            .task {
                self.appDelegate.bindWindowActions(open: self.openWindow, dismiss: self.dismissWindow)
            }
    }
}

private struct MenuBarContentView: View {
    let appDelegate: AppDelegate

    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        Button("Open Dashboard") {
            self.appDelegate.bindWindowActions(open: self.openWindow, dismiss: self.dismissWindow)
            self.appDelegate.showDashboard()
        }
        .globalKeyboardShortcut(.toggleDashboard)

        Divider()

        Button("Settings…") {
            self.appDelegate.showSettings()
        }
        .keyboardShortcut(",", modifiers: .command)

        Button("About…") {
            self.appDelegate.showSettings(tab: .about)
        }

        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}

// MARK: - App Delegate

@MainActor @Observable
class AppDelegate: NSObject, NSApplicationDelegate {
    static let dashboardWindowID = "dashboard"

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
    let pointOfInterestPresenter = PointOfInterestPresenter(fetch: { category, location in
        return try await PointOfInterestController().fetch(category: category, location: location)
    })

    let settingsSelection = SettingsSelection()
    var settingsPanel: NSPanel?

    @ObservationIgnored private var openWindowAction: OpenWindowAction?
    @ObservationIgnored private var dismissWindowAction: DismissWindowAction?
    @ObservationIgnored private weak var dashboardWindow: NSWindow?
    @ObservationIgnored private var themeObserver: NSObjectProtocol?
    @ObservationIgnored private var shutdownTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        AppSecrets.runSelfCheckIfRequested()
        #endif
        AppProcess.shared.start()
        self.pointOfInterestPresenter.start(updates: AppLocation.shared.updates())

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

    // MARK: - Dashboard Window

    func bindWindowActions(open: OpenWindowAction, dismiss: DismissWindowAction) -> Void {
        self.openWindowAction = open
        self.dismissWindowAction = dismiss
    }

    func registerDashboardWindow(_ window: NSWindow?) -> Void {
        self.dashboardWindow = window
    }

    func showDashboard() -> Void {
        self.openWindowAction?(id: Self.dashboardWindowID)
        self.frontDashboard(retries: 5)
    }

    private func frontDashboard(retries: Int) -> Void {
        if let window = self.dashboardWindow {
            NSRunningApplication.current.activate(options: [.activateAllWindows])
            NSApp.activate()
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            return
        }
        guard retries > 0 else { return }
        DispatchQueue.main.async { self.frontDashboard(retries: retries - 1) }
    }

    func hideDashboard() -> Void {
        if let dismiss = self.dismissWindowAction {
            dismiss(id: Self.dashboardWindowID)
        }
        else {
            self.dashboardWindow?.close()
        }
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
                particlePresenter: self.particlePresenter,
                surveyPresenter: self.surveyPresenter,
                fuelPresenter: self.fuelPresenter,
                pointOfInterestPresenter: self.pointOfInterestPresenter
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
