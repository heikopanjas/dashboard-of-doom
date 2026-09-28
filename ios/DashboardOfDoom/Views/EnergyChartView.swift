import DoomKitProcess
import DoomKitLocation
import DoomKitTools
import Charts
import SwiftUI

struct EnergyChartView: View {
    @Environment(EnergyPresenter.self) private var presenter
    @Environment(\.colorScheme) private var colorScheme
    @State private var timestamp: Date?
    @AppStorage(ForecastFamily.energy.key) private var showForecasts = ForecastFamily.enabledByDefault
    let selector: ProcessSelector

    private let labels: [ProcessSelector: String] = [
        .energy(.brent): "Brent Crude",
        .energy(.wti): "WTI Crude",
        .energy(.lng): "EU LNG"
    ]

    /// The forecast after the last measurement, while forecasts are switched on.
    private var forecast: ProcessForecast? {
        return self.showForecasts ? presenter.forecasts[self.selector] : nil
    }

    var body: some View {
        VStack {
            HStack(alignment: .bottom) {
                Text(self.labels[selector] ?? "<Unknown>")
                Spacer()
                if let forecast = self.forecast {
                    ForecastLegend(origin: forecast.origin, color: Color.chart)
                }
            }
            .font(.headline)
            .accentLabel()
            Chart {
                ForEach(presenter.measurements[selector] ?? []) { measurement in
                    LineMark(
                        x: .value("Date", measurement.timestamp),
                        y: .value("Value", measurement.value.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(.gray.opacity(0.0))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    // Anchored at the floor of the range, not at zero: the axis starts near the prices, and an area from zero would be
                    // painted far below the plot, behind whatever comes after the chart.
                    AreaMark(
                        x: .value("Date", measurement.timestamp),
                        yStart: .value("Floor", ForecastDisplay.domain(range: presenter.range[selector], forecast: self.forecast).lowerBound),
                        yEnd: .value("Value", measurement.value.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Gradient.linear)
                }

                if let forecast = self.forecast {
                    ForecastMarks(
                        forecast: forecast, anchor: presenter.measurements[selector]?.last, color: Color.chart, colorScheme: self.colorScheme, xLabel: "Date", yLabel: "Value")
                }

                if let measurement = presenter.current[selector] {
                    RuleMark(x: .value("Date", measurement.timestamp))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                        .foregroundStyle(self.colorScheme.markerColor)
                    PointMark(
                        x: .value("Date", measurement.timestamp),
                        y: .value("Value", measurement.value.value)
                    )
                    .symbolSize(CGSize(width: 7, height: 7))
                    .foregroundStyle(self.colorScheme.markerColor)
                    .annotation(position: .topLeading, spacing: 0, overflowResolution: .init(x: .fit, y: .fit)) {
                        VStack {
                            Text(measurement.timestamp.dateString())
                                .font(.footnote)
                            HStack {
                                Text(String(format: "%.2f %@", measurement.value.value, measurement.value.unit.symbol))
                                if let icon = presenter.trend[selector] {
                                    Image(systemName: icon)
                                }
                            }
                            .font(.headline)
                        }
                        .padding(7)
                        .padding(.horizontal, 7)
                        .quality(measurement.quality, opaque: false)
                    }
                }

                if let timestamp = self.timestamp {
                    if let measurement = presenter.measurements[selector]?.first(where: { $0.timestamp == timestamp }) {
                        RuleMark(x: .value("Date", timestamp))
                            .lineStyle(StrokeStyle(lineWidth: 1))
                            .foregroundStyle(self.colorScheme.markerColor)
                        PointMark(
                            x: .value("Date", timestamp),
                            y: .value("Value", measurement.value.value)
                        )
                        .symbolSize(CGSize(width: 7, height: 7))
                        .foregroundStyle(self.colorScheme.markerColor)
                        .annotation(position: .bottomLeading, spacing: 0, overflowResolution: .init(x: .fit, y: .fit)) {
                            VStack {
                                Text(timestamp.dateString())
                                    .font(.footnote)
                                HStack {
                                    Text(String(format: "%.2f %@", measurement.value.value, measurement.value.unit.symbol))
                                        .font(.headline)
                                }
                            }
                            .padding(7)
                            .padding(.horizontal, 7)
                            .quality(measurement.quality)
                        }
                    }
                    else if let forecast = self.forecast, let point = ForecastDisplay.point(at: timestamp, in: forecast) {
                        ForecastMarker(point: point, origin: forecast.origin, format: "%.2f %@", color: self.colorScheme.markerColor, xLabel: "Date", yLabel: "Value")
                    }
                }
            }
            .chartYScale(domain: ForecastDisplay.domain(range: presenter.range[selector], forecast: self.forecast))
            .chartInteractiveOverlay(timestamp: $timestamp, roundingStrategy: .lastDayChange)
        }
    }
}
