import SwiftUI

/// Text labels take the accent in dark mode and the system label color in light mode.
struct AccentLabel: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content.foregroundStyle(self.colorScheme == .light ? Color.primary : Color.accentColor)
    }
}

extension View {
    func accentLabel() -> some View {
        modifier(AccentLabel())
    }
}
