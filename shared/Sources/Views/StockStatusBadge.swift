import SwiftUI

/// EuroOilWatch's assessment of a fuel stock as a badge in the chart's title row, in the colors of the quality badges: red for critical,
/// orange for warning, yellow for watch, green for safe, gray for anything else.
struct StockStatusBadge: View {
    @Environment(\.colorScheme) private var colorScheme
    let status: String
    /// The month the assessment is for, `yyyy-MM`, read out by VoiceOver.
    var period: String?

    static func tint(for status: String) -> Color {
        switch status {
            case "critical":
                return .red
            case "warning":
                return .orange
            case "watch":
                return .yellow
            case "safe":
                return .green
            default:
                return .gray
        }
    }

    var body: some View {
        Text(self.status.capitalized)
            .font(.caption)
            .foregroundStyle(BadgeBackground.text)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(
                BadgeBackground(tint: Self.tint(for: self.status), opacity: 0.5, colorScheme: self.colorScheme, opaque: false)
            )
            .accessibilityLabel("Status \(self.status)" + (self.period.map { " in \($0)" } ?? ""))
    }
}
