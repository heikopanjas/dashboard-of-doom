import Foundation

/// Four distinct source screens between the fixed Home, Weather and Settings buttons.
struct IOSToolbarConfiguration: Equatable {
    static let storageKey = "ios.toolbar.screens"
    static let defaultScreens: [IOSScreen] = [.level, .radiation, .particles, .covid]
    private(set) var screens: [IOSScreen]

    init(storedValue: String = "") {
        if let decoded = try? JSONDecoder().decode([IOSScreen].self, from: Data(storedValue.utf8)),
            decoded.count == Self.defaultScreens.count,
            Set(decoded).count == decoded.count,
            decoded.allSatisfy({ IOSScreen.customizable.contains($0) })
        {
            self.screens = decoded
        }
        else {
            self.screens = Self.defaultScreens
        }
    }

    var storedValue: String {
        guard let data = try? JSONEncoder().encode(self.screens) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    /// Assigning an existing screen swaps positions. A disabled replacement never opens its screen.
    mutating func assign(_ screen: IOSScreen, to slot: Int, selected: IOSScreen, enabled: Bool) -> IOSScreen {
        guard self.screens.indices.contains(slot), IOSScreen.customizable.contains(screen) == true else { return selected }
        if let previousSlot = self.screens.firstIndex(of: screen) {
            self.screens.swapAt(slot, previousSlot)
        }
        else {
            self.screens[slot] = screen
        }
        if enabled == true {
            return screen
        }
        return self.contains(selected) == true ? selected : .home
    }

    func contains(_ screen: IOSScreen) -> Bool {
        return [.home, .weather, .settings].contains(screen) || self.screens.contains(screen)
    }
}
