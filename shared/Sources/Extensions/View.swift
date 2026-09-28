import DoomKitProcess
import SwiftUI

/// The badge behind a chart marker's label, tinted by the value's quality. The tint is half transparent over an opaque base, so the chart
/// underneath never shows through; the base follows the appearance, white in light mode and black in dark mode. The current value's badge
/// draws the tint without the base (`opaque: false`), so the chart shows through. The text is black on every badge in both appearances,
/// the user's choice. On the dark base the uncertain orange is stronger, since at half strength it was too dark for the black text.
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

    var tintOpacity: Double {
        return self.opaque && self.colorScheme == .dark && self.qualityCode == .uncertain ? 0.75 : 0.5
    }

    func body(content: Content) -> some View {
        content
            .background(BadgeBackground(tint: self.backgroundColor, opacity: self.tintOpacity, colorScheme: self.colorScheme, opaque: self.opaque))
            .foregroundStyle(BadgeBackground.text)
    }
}

/// A rounded badge: the base for the appearance, the tint over it. Without the base (`opaque: false`) only the tint is drawn.
struct BadgeBackground: View {
    static let text = Color.black

    let tint: Color
    let opacity: Double
    let colorScheme: ColorScheme
    var opaque: Bool = true

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



