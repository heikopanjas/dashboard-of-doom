import DoomKitProcess
import SwiftUI

/// The badge behind a chart marker's label, tinted by the value's quality. The tint is half transparent over an opaque base, so the chart
/// underneath never shows through, and the base and the text follow the appearance: white under black text in light mode, black under
/// white text in dark mode. Half-transparent over the chart alone, with black text, it was dark green on black in dark mode, with the
/// area showing through, and at some values the reading could not be read. The current value's badge stays half transparent without the
/// base (`opaque: false`), as it always was; the user wants the chart to show through there. Its text still follows the appearance.
struct QualityCodeViewModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var qualityCode: ProcessQuality
    var opaque: Bool = true

    var backgroundColor: Color {
        switch qualityCode {
            case .good:
                return .green
            case .uncertain:
                return .orange
            case .bad:
                return .red
            default:
                return .gray
        }
    }

    func body(content: Content) -> some View {
        content
            .background(BadgeBackground(tint: self.backgroundColor, opacity: 0.5, colorScheme: self.colorScheme, opaque: self.opaque))
            .foregroundStyle(BadgeBackground.text(for: self.colorScheme))
    }
}

/// A rounded badge: the base for the appearance, the tint over it. Without the base (`opaque: false`) only the tint is drawn.
struct BadgeBackground: View {
    let tint: Color
    let opacity: Double
    let colorScheme: ColorScheme
    var opaque: Bool = true

    static func text(for colorScheme: ColorScheme) -> Color {
        return colorScheme == .dark ? .white : .black
    }

    var body: some View {
        ZStack {
            if self.opaque {
                RoundedRectangle(cornerRadius: 13)
                    .fill(self.colorScheme == .dark ? Color.black : Color.white)
            }
            RoundedRectangle(cornerRadius: 13)
                .fill(self.tint.opacity(self.opacity))
        }
    }
}

extension View {
    func quality(_ quality: ProcessQuality, opaque: Bool = true) -> some View {
        self.modifier(QualityCodeViewModifier(qualityCode: quality, opaque: opaque))
    }
}



