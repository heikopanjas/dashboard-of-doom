import DoomKitProcess
import SwiftUI

/// The Warnings tab: NINA warnings near the user, or a green all-clear when there are none. A failed refresh keeps the last list and adds
/// a line; it never shows a false all-clear. The rows are the ones the iOS home card shows.
struct WarningsView: View {
    @Environment(HazardPresenter.self) private var presenter
    @AppStorage("showHazards") private var showHazards: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // The presenter never leaves `.loading` while switched off, so without this the tab would spin forever.
            if self.showHazards == false {
                self.switchedOff
            }
            else {
                switch (self.presenter.state, self.presenter.timestamp) {
                    case (.loading, nil):
                        ActivityIndicator()
                    case (.failed(let message), nil):
                        self.header
                        self.failureLine(message)
                        Spacer()
                    default:
                        self.header
                        ScrollView {
                            VStack(alignment: .leading, spacing: 8) {
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
                                        WarningRow(hazard: hazard)
                                    }
                                }
                                if case .failed(let message) = self.presenter.state {
                                    self.failureLine(message)
                                }
                            }
                        }
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            HStack {
                Image(systemName: "exclamationmark.triangle")
                Text("Warnings nearby")
            }
            Spacer()
            Text("Last update: \(Date.absoluteString(date: self.presenter.timestamp))")
                .foregroundColor(.gray)
        }
        .font(.footnote)
    }

    private var switchedOff: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
            Text("Warnings are switched off in Settings.")
                .foregroundColor(.gray)
            Spacer()
        }
        .frame(maxWidth: .infinity)
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

/// Clicking a row opens the alert's page on NINA in the default browser.
private struct WarningRow: View {
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
                // The tab has the room the iOS card does not, so the text is not cut short.
                Text(self.hazard.instruction ?? self.hazard.description)
                    .font(.footnote)
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
