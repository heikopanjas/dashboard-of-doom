import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// System-wide dashboard toggle. `initial:` seeds the default once; the user's
    /// choice in Settings > General overrides it thereafter.
    static let toggleDashboard = Self("toggleDashboard", initial: .init(.d, modifiers: [.command, .control]))
}
