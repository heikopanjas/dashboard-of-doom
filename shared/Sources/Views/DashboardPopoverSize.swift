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
#endif
