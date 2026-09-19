import DoomKitProcess
import DoomKitLocation
import DoomKitTools
import Charts
import SwiftUI

struct ForecastChartView: View {
    @Environment(ForecastPresenter.self) private var presenter
    @State private var timestamp: Date?
    let selector: ProcessSelector

    private let labels: [ProcessSelector: String] = [
        .forecast(.temperature): "Temperature (actual)",
        .forecast(.apparentTemperature): "Temperature (feels like)",
        .forecast(.dewPoint): "Dew Point",
        .forecast(.humidity): "Humidity",
        .forecast(.precipitationChance): "Precipitation Chance",
        .forecast(.precipitationAmount): "Precipitation Amount",
        .forecast(.pressure): "Pressure",
        .forecast(.visibility): "Visibility",
        .forecast(.cloudCover): "Cloud Cover",
        .forecast(.windSpeed): "Wind Speed",
        .forecast(.windGust): "Wind Gusts"
    ]

    var body: some View {
        VStack {
            HStack(alignment: .bottom) {
                Text("\(self.labels[selector] ?? "<Unknown>")")
                Spacer()
            }
            .font(.headline)
            .accentLabel()
            Chart {
                ForEach(presenter.measurements[selector] ?? []) { measurement in
                    AreaMark(
                        x: .value("Date", Date.round(from: measurement.timestamp, strategy: .previousHour) ?? Date.now),
                        yStart: .value("Forecast", presenter.range[selector]?.lowerBound ?? 0.0),
                        yEnd: .value("Forecast", measurement.value.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Gradient.linear)
                }

                if let measurement = presenter.current[selector] {
                    RuleMark(x: .value("Date", measurement.timestamp))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                    PointMark(
                        x: .value("Date", measurement.timestamp),
                        y: .value("Forecast", measurement.value.value)
                    )
                    .symbolSize(CGSize(width: 7, height: 7))
                    .annotation(position: .topTrailing, spacing: 0, overflowResolution: .init(x: .fit, y: .fit)) {
                        VStack {
                            Text(String(format: "%@ %@", measurement.timestamp.dateString(), measurement.timestamp.timeString()))
                                .font(.footnote)
                            HStack {
                                if let icon = measurement.customData?["icon"] as? String {
                                    Image(systemName: icon)
                                }
                                Text(String(format: "%.1f%@", measurement.value.value, measurement.value.unit.symbol))
                                if let icon = presenter.trend[selector] {
                                    Image(systemName: icon)
                                }
                            }
                            .font(.headline)
                        }
                        .padding(7)
                        .padding(.horizontal, 7)
                        .quality(measurement.quality)
                    }
                }

                if let timestamp = self.timestamp {
                    if let measurement = presenter.measurements[selector]?.first(where: { $0.timestamp == timestamp }) {
                        RuleMark(x: .value("Date", Date.round(from: timestamp, strategy: .previousHour) ?? Date.now))
                            .lineStyle(StrokeStyle(lineWidth: 1))
                        PointMark(
                            x: .value("Date", timestamp),
                            y: .value("Forecast", measurement.value.value)
                        )
                        .symbolSize(CGSize(width: 7, height: 7))
                        .annotation(position: .bottomTrailing, spacing: 0, overflowResolution: .init(x: .fit, y: .fit)) {
                            VStack {
                                Text(String(format: "%@ %@", timestamp.dateString(), timestamp.timeString()))
                                    .font(.footnote)
                                HStack {
                                    if let icon = measurement.customData?["icon"] as? String {
                                        Image(systemName: icon)
                                    }
                                    Text(String(format: "%.1f%@", measurement.value.value, measurement.value.unit.symbol))
                                        .font(.headline)
                                }
                            }
                            .padding(7)
                            .padding(.horizontal, 7)
                            .quality(measurement.quality)
                        }
                    }
                }
            }
            .chartYScale(domain: presenter.range[selector] ?? 0.0 ... 0.0)
            .chartInteractiveOverlay(timestamp: $timestamp, roundingStrategy: .previousHour)
        }
    }
}
