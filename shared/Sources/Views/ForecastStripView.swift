import DoomKitProcess
import SwiftUI

/// The next 24 hours as a horizontal strip: hour, condition, temperature, rain chance.
struct ForecastStripView: View {
    @Environment(ForecastPresenter.self) private var presenter

    /// One column. Temperature and rain chance are paired by exact timestamp.
    struct Hour: Identifiable {
        let timestamp: Date
        let icon: String?
        let temperature: Measurement<Dimension>
        let precipitationChance: Double?
        var id: Date { return self.timestamp }
    }

    static let hourLimit = 24

    /// Hours from `start` onwards, oldest first, at most `limit`. An hour without a
    /// chance value is kept with a nil chance rather than dropped.
    static func hours(
        temperature: [ProcessValue<Dimension>], precipitation: [ProcessValue<Dimension>],
        from start: Date, limit: Int = ForecastStripView.hourLimit
    ) -> [Hour] {
        let chance = Dictionary(
            precipitation.map { ($0.timestamp, $0.value.value) }, uniquingKeysWith: { first, _ in first })
        return temperature
            .filter { $0.timestamp >= start }
            .sorted { $0.timestamp < $1.timestamp }
            .prefix(limit)
            .map { value in
                Hour(
                    timestamp: value.timestamp, icon: value.customData?["icon"] as? String,
                    temperature: value.value, precipitationChance: chance[value.timestamp])
            }
    }

    /// The transformer already rounds `current` to the next hour, so the first column
    /// matches the marker hour on the Weather tab.
    private var start: Date {
        return self.presenter.current[.forecast(.temperature)]?.timestamp
            ?? Date.round(from: Date.now, strategy: .nextHour)
            ?? Date.now
    }

    private var hours: [Hour] {
        return Self.hours(
            temperature: self.presenter.measurements[.forecast(.temperature)] ?? [],
            precipitation: self.presenter.measurements[.forecast(.precipitationChance)] ?? [],
            from: self.start)
    }

    var body: some View {
        VStack {
            if self.presenter.timestamp == nil {
                ActivityIndicator()
            }
            else {
                HStack {
                    Text("Next 24 hours")
                    Spacer()
                }
                .font(.headline)
                .accentLabel()
                let hours = self.hours
                if hours.isEmpty {
                    HStack {
                        Text("No forecast available")
                            .font(.footnote)
                            .foregroundColor(.gray)
                        Spacer()
                    }
                }
                else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 14) {
                            ForEach(hours) { hour in
                                ForecastHourColumn(hour: hour, fallbackIcon: self.presenter.icon)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .accessibilityLabel("Hourly forecast")
                }
            }
        }
    }
}

private struct ForecastHourColumn: View {
    let hour: ForecastStripView.Hour
    let fallbackIcon: String

    var body: some View {
        VStack(spacing: 4) {
            Text(self.hour.timestamp.timeString())
                .font(.footnote)
                .foregroundColor(.gray)
            Image(systemName: self.hour.icon ?? self.fallbackIcon)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(minHeight: 24)
            Text(String(format: "%.0f°", self.hour.temperature.value))
                .font(.callout)
                .monospacedDigit()
            Text(self.hour.precipitationChance.map { String(format: "%.0f%%", $0) } ?? "–")
                .font(.footnote)
                .foregroundColor(.gray)
                .monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(self.accessibilityText)
    }

    private var accessibilityText: String {
        var parts = [self.hour.timestamp.timeString()]
        if let icon = self.hour.icon {
            parts.append(icon.replacingOccurrences(of: ".fill", with: "").replacingOccurrences(of: ".", with: " "))
        }
        parts.append(String(format: "%.0f degrees", self.hour.temperature.value))
        if let chance = self.hour.precipitationChance {
            parts.append(String(format: "%.0f percent chance of precipitation", chance))
        }
        return parts.joined(separator: ", ")
    }
}
