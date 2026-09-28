#if os(macOS)
import CoreGraphics

/// The size of the dashboard popup under the status item. The dashboard's content needs at least 700 by 720 points; the popup is 800
/// wide and as tall as it can be up to 860, leaving a margin below the menu bar, so a small display such as a 13-inch MacBook Air still
/// fits it. It cannot be resized by dragging, so the size is decided here.
enum DashboardPopoverSize {
    static let width: CGFloat = 800
    static let preferredHeight: CGFloat = 860
    static let minimumHeight: CGFloat = 720
    static let margin: CGFloat = 40

    /// `visibleHeight` is the height of the screen below the menu bar and above the Dock.
    static func size(visibleHeight: CGFloat) -> CGSize {
        let height = max(min(Self.preferredHeight, visibleHeight - Self.margin), Self.minimumHeight)
        return CGSize(width: Self.width, height: height)
    }
}

/// Where the dashboard popup is anchored, in screen coordinates. The popup hangs from an invisible window at the status item's position
/// rather than from the item itself, because menu bar managers such as Ice and Bartender move the item off screen when they rehide their
/// section, which a click inside the popup triggers, and a popover closes when the view it hangs from leaves the screen.
enum DashboardPopoverAnchor {
    static let fallbackWidth: CGFloat = 22
    static let fallbackInset: CGFloat = 8

    /// `button` is the status item's frame on screen, nil without a window; `screens` are the frames of all screens. A button no screen
    /// shows, hidden by a menu bar manager, gives a place at the right end of the menu bar on `menuBarScreen`.
    static func rect(button: CGRect?, screens: [CGRect], menuBarScreen: CGRect?, menuBarHeight: CGFloat) -> CGRect {
        if let button, screens.contains(where: { $0.contains(CGPoint(x: button.midX, y: button.midY)) }) {
            return button
        }
        guard let screen = menuBarScreen else { return button ?? .zero }
        return CGRect(
            x: screen.maxX - Self.fallbackInset - Self.fallbackWidth,
            y: screen.maxY - menuBarHeight,
            width: Self.fallbackWidth,
            height: menuBarHeight
        )
    }
}
#endif
