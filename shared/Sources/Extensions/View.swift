import DoomKitProcess
import SwiftUI

/// The badge behind a chart marker's label, tinted by the value's quality. The tint is half transparent over an opaque base, so the chart
/// underneath never shows through, and the base and the text follow the appearance: white under black text in light mode, black under
/// white text in dark mode. Half-transparent over the chart alone, with black text, it was dark green on black in dark mode, with the
/// area showing through, and at some values the reading could not be read.
struct QualityCodeViewModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var qualityCode: ProcessQuality

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
            .background(BadgeBackground(tint: self.backgroundColor, opacity: 0.5, colorScheme: self.colorScheme))
            .foregroundStyle(BadgeBackground.text(for: self.colorScheme))
    }
}

/// An opaque rounded badge: the base for the appearance, the tint over it.
struct BadgeBackground: View {
    let tint: Color
    let opacity: Double
    let colorScheme: ColorScheme

    static func text(for colorScheme: ColorScheme) -> Color {
        return colorScheme == .dark ? .white : .black
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13)
                .fill(self.colorScheme == .dark ? Color.black : Color.white)
            RoundedRectangle(cornerRadius: 13)
                .fill(self.tint.opacity(self.opacity))
        }
    }
}

extension View {
    func quality(_ quality: ProcessQuality) -> some View {
        self.modifier(QualityCodeViewModifier(qualityCode: quality))
    }
}



