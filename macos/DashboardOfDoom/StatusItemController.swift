import AppKit
import DoomKitProcess
import KeyboardShortcuts

/// The menu bar status item: one or two chosen values, and the menu behind it. An AppKit `NSStatusItem` rather than a SwiftUI
/// `MenuBarExtra`, because a menu bar extra's label cannot hold the custom drawn view that stacks two values.
@MainActor
final class StatusItemController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let displayView = StatusItemDisplayView()
    private weak var appDelegate: AppDelegate?
    private var defaultsObserver: NSObjectProtocol?
    private var shownValues: [String] = []

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        super.init()
        self.statusItem.menu = self.makeMenu()
        self.statusItem.button?.addSubview(self.displayView)
        // The selection and the source switches live in the settings, which Observation does not see.
        self.defaultsObserver = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) {
            [weak self] _ in
            MainActor.assumeIsolated { self?.update() }
        }
        self.observe()
    }

    /// The text for these values: the nearest reading's faceplate, the string the map labels show.
    static func texts(for values: [StatusBarValue], faceplate: (StatusBarValue) -> String?) -> [String] {
        return values.map { faceplate($0) ?? "n/a" }
    }

    /// Re-registers after every change, so the rows follow the readings they read.
    private func observe() -> Void {
        withObservationTracking {
            self.update()
        } onChange: {
            Task { @MainActor [weak self] in self?.observe() }
        }
    }

    private func update() -> Void {
        let values = Self.texts(for: StatusBarPreferences.displayed()) { value in
            return self.appDelegate?.faceplate(for: value)
        }
        guard values != self.shownValues, let button = self.statusItem.button else { return }
        self.shownValues = values
        let width = StatusItemDisplayView.requiredWidth(for: values)
        let height = button.bounds.height > 0 ? button.bounds.height : NSStatusBar.system.thickness
        self.statusItem.length = width
        self.displayView.frame = NSRect(x: 0, y: 0, width: width, height: height)
        self.displayView.autoresizingMask = [.height]
        self.displayView.configure(values: values)
        button.setAccessibilityLabel(values.joined(separator: ", "))
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        let dashboard = NSMenuItem(title: "Open Dashboard", action: #selector(self.openDashboard), keyEquivalent: "")
        // Shows the global shortcut from Settings > General next to the item, as the SwiftUI menu did.
        dashboard.setShortcut(for: .toggleDashboard)
        menu.addItem(dashboard)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(self.openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "About…", action: #selector(self.openAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(self.quit), keyEquivalent: "q"))
        for item in menu.items where item.isSeparatorItem == false {
            item.target = self
        }
        return menu
    }

    @objc private func openDashboard() {
        self.appDelegate?.showDashboard()
    }

    @objc private func openSettings() {
        self.appDelegate?.showSettings()
    }

    @objc private func openAbout() {
        self.appDelegate?.showSettings(tab: .about)
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
