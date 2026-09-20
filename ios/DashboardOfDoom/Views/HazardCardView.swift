import DoomKitProcess
import SwiftUI

/// NINA warnings near the user, or a green all-clear when there are none.
/// A failed refresh keeps the last list and adds a line; it never shows a
/// false all-clear.
struct HazardCardView: View {
    @Environment(HazardPresenter.self) private var presenter

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch (self.presenter.state, self.presenter.timestamp) {
                case (.loading, nil):
                    ActivityIndicator()
                case (.failed(let message), nil):
                    self.header
                    self.failureLine(message)
                default:
                    self.header
                    if self.presenter.hazards.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("No warnings near you")
                        }
                        .font(.footnote)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .quality(.good)
                    }
                    else {
                        ForEach(self.presenter.hazards) { hazard in
                            HazardRow(hazard: hazard)
                        }
                    }
                    if case .failed(let message) = self.presenter.state {
                        self.failureLine(message)
                    }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: "exclamationmark.triangle")
                Text("Warnings nearby")
                Spacer()
            }
            .accentLabel()
            HStack {
                Text("Last update: \(Date.absoluteString(date: self.presenter.timestamp))")
                Spacer()
            }
            .foregroundColor(.gray)
        }
        .font(.footnote)
    }

    private func failureLine(_ message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "wifi.exclamationmark")
            Text("Update failed: \(message)")
            Spacer()
        }
        .font(.caption)
        .foregroundColor(.gray)
    }
}

/// Tapping a row opens the alert's page on NINA in the system browser.
private struct HazardRow: View {
    @Environment(\.openURL) private var openURL
    let hazard: Hazard

    var body: some View {
        Button {
            if let url = self.hazard.sourceURL { self.openURL(url) }
        } label: {
            self.content
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the alert on warnung.bund.de")
    }

    private var content: some View {
        HStack(alignment: .top, spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(self.hazard.severity.color)
                .frame(width: 4)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text(self.hazard.headline)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    Text(self.hazard.severity.label)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(self.hazard.severity.color.opacity(0.3)))
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .accessibilityHidden(true)
                }
                // DWD lists every municipality in the area, hundreds for a county-wide warning.
                Text(self.hazard.areaLabel)
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .lineLimit(2)
                Text(self.hazard.instruction ?? self.hazard.description)
                    .font(.footnote)
                    .lineLimit(3)
                Text(Self.timeLabel(self.hazard))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    /// Full dates on both ends: a warning sent yesterday evening must not read as today's.
    static func timeLabel(_ hazard: Hazard) -> String {
        var label = "since \(Date.absoluteString(date: hazard.sent))"
        if let expires = hazard.expires {
            label += " · until \(Date.absoluteString(date: expires))"
        }
        return label
    }
}
