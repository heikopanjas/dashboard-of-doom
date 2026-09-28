import Charts
import DoomKitProcess
import SwiftUI

/// A forecast after a series' last measurement: its uncertainty band as a translucent range, its value as a solid line in the series'
/// color, both starting where the measurements end, and a hairline at now. The measured series stays the filled area, so the two can
/// always be told apart.
struct ForecastMarks: ChartContent {
    let forecast: ProcessForecast
    /// The last measurement, where the line and the band start, so the forecast continues the series instead of floating beside it.
    let anchor: ProcessValue<Dimension>?
    let color: Color
    var xLabel = "Date"
    var yLabel = "Value"

    private struct Sample: Identifiable {
        let timestamp: Date
        let value: Double
        let lower: Double
        let upper: Double

        var id: Date {
            return self.timestamp
        }
    }

    private var samples: [Sample] {
        var samples = self.forecast.points.map { point in
            Sample(timestamp: point.timestamp, value: point.value.value, lower: point.lower ?? point.value.value, upper: point.upper ?? point.value.value)
        }
        if let anchor = self.anchor, anchor.timestamp < (samples.first?.timestamp ?? .distantPast) {
            let value = anchor.value.value
            samples.insert(Sample(timestamp: anchor.timestamp, value: value, lower: value, upper: value), at: 0)
        }
        return samples
    }

    var body: some ChartContent {
        let samples = self.samples
        if self.forecast.points.contains(where: \.hasBand) {
            ForEach(samples) { sample in
                AreaMark(
                    x: .value(self.xLabel, sample.timestamp),
                    yStart: .value(self.yLabel, sample.lower),
                    yEnd: .value(self.yLabel, sample.upper),
                    series: .value("Series", "band")
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(self.color.opacity(0.18))
            }
        }
        ForEach(samples) { sample in
            LineMark(
                x: .value(self.xLabel, sample.timestamp),
                y: .value(self.yLabel, sample.value),
                series: .value("Series", "forecast")
            )
            .interpolationMethod(.monotone)
            .foregroundStyle(self.color)
            // Solid: a dashed line broke an hourly forecast into dots that could not be read as a series.
            .lineStyle(StrokeStyle(lineWidth: 1.5))
        }
        // `Color.secondary`, not `.secondary`: in a chart the hierarchical style derives from the accent color and draws the rule blue.
        RuleMark(x: .value(self.xLabel, Date.now))
            .lineStyle(StrokeStyle(lineWidth: 0.5))
            .foregroundStyle(Color.secondary)
    }
}

/// The drag marker on a forecast point: the same rule and dot as on a measurement, with a label that says whose forecast it is.
struct ForecastMarker: ChartContent {
    let point: ProcessForecast.Point
    let origin: ProcessForecast.Origin
    /// The chart's own value format, such as `%.2f%@`.
    let format: String
    let color: Color
    var xLabel = "Date"
    var yLabel = "Value"

    var body: some ChartContent {
        RuleMark(x: .value(self.xLabel, self.point.timestamp))
            .lineStyle(StrokeStyle(lineWidth: 1))
            .foregroundStyle(self.color)
        PointMark(
            x: .value(self.xLabel, self.point.timestamp),
            y: .value(self.yLabel, self.point.value.value)
        )
        .symbolSize(CGSize(width: 7, height: 7))
        .foregroundStyle(self.color)
        .annotation(position: .bottomLeading, spacing: 0, overflowResolution: .init(x: .fit, y: .fit)) {
            VStack {
                Text(String(format: "%@ %@", self.point.timestamp.dateString(), self.point.timestamp.timeString()))
                    .font(.footnote)
                Text(String(format: self.format, self.point.value.value, self.point.value.unit.symbol))
                    .font(.headline)
                if let lower = self.point.lower, let upper = self.point.upper {
                    Text(String(format: "\(self.format) – \(self.format)", lower, self.point.value.unit.symbol, upper, self.point.value.unit.symbol))
                        .font(.caption2)
                }
                Text(ForecastDisplay.label(for: self.origin))
                    .font(.caption2)
            }
            .padding(7)
            .padding(.horizontal, 7)
            .forecastBadge()
        }
    }
}

/// The legend in a chart's title row: a line swatch and whose forecast the line is.
struct ForecastLegend: View {
    let origin: ProcessForecast.Origin
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Path { path in
                path.move(to: CGPoint(x: 0, y: 4))
                path.addLine(to: CGPoint(x: 16, y: 4))
            }
            .stroke(self.color, style: StrokeStyle(lineWidth: 1.5))
            .frame(width: 16, height: 8)
            Text(ForecastDisplay.legend(for: self.origin))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

/// The badge behind a forecast marker's label: neutral and outlined, where a measurement's badge is colored by its quality.
struct ForecastBadgeViewModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: 13).fill(Color.gray.opacity(0.35)))
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(Color.secondary, lineWidth: 1))
            .foregroundStyle(Color.primary)
    }
}

extension View {
    func forecastBadge() -> some View {
        self.modifier(ForecastBadgeViewModifier())
    }
}
