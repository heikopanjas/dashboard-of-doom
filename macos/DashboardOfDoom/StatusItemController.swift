import AppKit
import DoomKitProcess
import SwiftUI

/// The menu bar status item: one or two chosen values, the dashboard in a popup on a click, and a menu on a right click. An AppKit
/// `NSStatusItem` rather than a SwiftUI `MenuBarExtra`, because a menu bar extra's label cannot hold the custom drawn view that stacks two
/// values.
@MainActor
final class StatusItemController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let displayView = StatusItemDisplayView()
    private let popover = NSPopover()
    private lazy var menu = self.makeMenu()
    private weak var appDelegate: AppDelegate?
    private var defaultsObserver: NSObjectProtocol?
    private var shownValues: [String] = []

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        super.init()
        if let button = self.statusItem.button {
            button.addSubview(self.displayView)
            // No menu on the item itself, so a left click reaches the action; a right click shows the menu from there.
            button.target = self
            button.action = #selector(self.clicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        // Built once and kept, so the dashboard keeps its tab when the popup closes. Transient: a click elsewhere closes it.
        self.popover.behavior = .transient
        self.popover.animates = true
        self.popover.contentViewController = NSHostingController(rootView: DashboardRootView(appDelegate: appDelegate))
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

    // MARK: - Clicks

    /// A left click toggles the dashboard popup; a right click, or a left click with Control, shows the menu.
    @objc private func clicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            self.showMenu()
        }
        else {
            self.togglePopover()
        }
    }

    /// Opens or closes the dashboard under the status item; the global shortcut calls this too.
    func togglePopover() -> Void {
        if self.popover.isShown == true {
            self.popover.performClose(nil)
            return
        }
        guard let button = self.statusItem.button else { return }
        let visibleHeight = (button.window?.screen ?? NSScreen.main)?.visibleFrame.height ?? DashboardPopoverSize.preferredHeight
        self.popover.contentSize = DashboardPopoverSize.size(visibleHeight: visibleHeight)
        // The app has no Dock icon and is never active on its own, so it activates first for the popup to take keyboard focus.
        NSApp.activate()
        self.popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    /// The menu anchored to the item: assigned for one click and removed again, so a left click keeps reaching the action.
    private func showMenu() -> Void {
        self.popover.performClose(nil)
        self.statusItem.menu = self.menu
        self.statusItem.button?.performClick(nil)
        self.statusItem.menu = nil
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(self.openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "About…", action: #selector(self.openAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(self.quit), keyEquivalent: "q"))
        for item in menu.items where item.isSeparatorItem == false {
            item.target = self
        }
        return menu
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
