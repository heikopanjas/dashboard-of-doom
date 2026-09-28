import DoomKitProcess
import DoomKitLocation
import DoomKitTools
import Charts
import SwiftUI

struct RadiationChartView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var timestamp: Date?
    @AppStorage(ForecastFamily.radiation.key) private var showForecasts = ForecastFamily.enabledByDefault
    let selector: ProcessSelector
    let reading: ProcessReading

    private let labels: [ProcessSelector: String] = [
        .radiation(.total): "Radiation"
    ]

    /// The forecast after the last measurement, while forecasts are switched on.
    private var forecast: ProcessForecast? {
        return self.showForecasts ? self.reading.forecasts[self.selector] : nil
    }

    var body: some View {
        VStack {
            HStack(alignment: .bottom) {
                Text("\(self.reading.sensor.name) \(self.labels[selector] ?? "<Unknown>")")
                Spacer()
                if let forecast = self.forecast {
                    ForecastLegend(origin: forecast.origin, color: Color.chart)
                }
            }
            .font(.headline)
            .accentLabel()
            Chart {
                ForEach(self.reading.measurements[selector] ?? []) { radiation in
                    LineMark(
                        x: .value("Date", radiation.timestamp),
                        y: .value("Radiation", radiation.value.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(.gray.opacity(0.0))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    AreaMark(
                        x: .value("Date", radiation.timestamp),
                        y: .value("Radiation", radiation.value.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Gradient.linear)
                }

                if let forecast = self.forecast {
                    ForecastMarks(
                        forecast: forecast, anchor: self.reading.measurements[selector]?.last, color: Color.chart, colorScheme: self.colorScheme, xLabel: "Date", yLabel: "Radiation")
                }

                if let measurement = self.reading.current[selector] {
                    RuleMark(x: .value("Date", measurement.timestamp))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                        .foregroundStyle(self.colorScheme.markerColor)
                    PointMark(
                        x: .value("Date", measurement.timestamp),
                        y: .value("Radiation", measurement.value.value)
                    )
                    .symbolSize(CGSize(width: 7, height: 7))
                    .foregroundStyle(self.colorScheme.markerColor)
                    .annotation(position: .topLeading, spacing: 0, overflowResolution: .init(x: .fit, y: .fit)) {
                        VStack {
                            Text(String(format: "%@ %@", measurement.timestamp.dateString(), measurement.timestamp.timeString()))
                                .font(.footnote)
                            HStack {
                                Text(String(format: "%.3f%@", measurement.value.value, measurement.value.unit.symbol))
                                if let icon = self.reading.trend[selector] {
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
                    if let measurement = self.reading.measurements[selector]?.first(where: { $0.timestamp == timestamp }) {
                        RuleMark(x: .value("Date", timestamp))
                            .lineStyle(StrokeStyle(lineWidth: 1))
                            .foregroundStyle(self.colorScheme.markerColor)
                        PointMark(
                            x: .value("Date", timestamp),
                            y: .value("Radiation", measurement.value.value)
                        )
                        .symbolSize(CGSize(width: 7, height: 7))
                        .foregroundStyle(self.colorScheme.markerColor)
                        .annotation(position: .bottomLeading, spacing: 0, overflowResolution: .init(x: .fit, y: .fit)) {
                            VStack {
                                Text(String(format: "%@ %@", timestamp.dateString(), timestamp.timeString()))
                                    .font(.footnote)
                                HStack {
                                    Text(String(format: "%.3f%@", measurement.value.value, measurement.value.unit.symbol))
                                        .font(.headline)
                                }
                            }
                            .padding(7)
                            .padding(.horizontal, 7)
                            .quality(measurement.quality)
                        }
                    }
                    else if let forecast = self.forecast, let point = ForecastDisplay.point(at: timestamp, in: forecast) {
                        ForecastMarker(point: point, origin: forecast.origin, format: "%.3f%@", color: self.colorScheme.markerColor, xLabel: "Date", yLabel: "Radiation")
                    }
                }

            }
            .chartYScale(domain: ForecastDisplay.domain(range: self.reading.range[selector], forecast: self.forecast))
            .chartInteractiveOverlay(timestamp: $timestamp, roundingStrategy: .previousHour)
        }
    }
}
