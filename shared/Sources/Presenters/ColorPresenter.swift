import Foundation
import SwiftUI

@Observable class ColorPresenter {
    struct Accent: Identifiable, Equatable {
        let id: String
        let label: String
        let color: Color
    }

    private static let orange = Accent(id: "orange", label: "Orange", color: .orange)
    private static let cyan = Accent(id: "cyan", label: "Cyan", color: .cyan)
    private static let blue = Accent(id: "blue", label: "Blue", color: .blue)

    static let accents: [Accent] = [orange, cyan, blue]
    static let defaultAccent = cyan
    static let storageKey = "selectedColor"

    // Accents retired when the palette shrank to three, mapped to the closest
    // survivor. White, gray and black have no near equivalent.
    private static let retiredAccents: [String: Accent] = [
        "red": orange, "yellow": orange, "brown": orange, "pink": orange,
        "green": cyan, "mint": cyan, "teal": cyan,
        "indigo": blue, "purple": blue,
    ]

    private(set) var selectedAccent: Accent
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.string(forKey: Self.storageKey)
        let accent = Self.resolveAccent(named: stored)
        self.selectedAccent = accent
        if let stored, stored != accent.id {
            defaults.set(accent.id, forKey: Self.storageKey)
        }
    }

    /// The accent only applies in dark mode. Light mode returns nil, which lets
    /// the AccentColor asset (system blue) show through. The stored choice is
    /// kept so it is still there when the app returns to dark mode.
    func tint(for scheme: ColorScheme) -> Color? {
        scheme == .dark ? self.selectedAccent.color : nil
    }

    func selectAccent(_ name: String) {
        guard let accent = Self.accents.first(where: { $0.id == name }) else { return }
        self.defaults.set(accent.id, forKey: Self.storageKey)
        self.selectedAccent = accent
    }

    static func resolveAccent(named name: String?) -> Accent {
        guard let name else { return self.defaultAccent }
        return self.accents.first(where: { $0.id == name })
            ?? self.retiredAccents[name]
            ?? self.defaultAccent
    }
}
