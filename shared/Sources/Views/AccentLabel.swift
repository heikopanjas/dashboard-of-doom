import SwiftUI

/// Text labels take the accent in dark mode and the system label color in light mode. On macOS the dashboard window sets its own label
/// colors, primary in light mode and cyan in dark mode, so the modifier leaves the content as it is there.
struct AccentLabel: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        #if os(macOS)
        content
        #else
        content.foregroundStyle(self.colorScheme == .light ? Color.primary : Color.accentColor)
        #endif
    }
}

extension View {
    func accentLabel() -> some View {
        modifier(AccentLabel())
    }
}

extension ColorScheme {
    /// Chart markers match the axis labels (the default secondary label color) in light mode
    /// and take the accent in dark mode.
    var markerColor: Color { self == .light ? Color.secondary : Color.accentColor }
}
