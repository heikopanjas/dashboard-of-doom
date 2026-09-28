import DoomKitProcess
import Charts
import SwiftUI

struct CovidChartView: View {
    @Environment(CovidPresenter.self) private var presenter
    @State private var timestamp: Date?
    @AppStorage(SourcePreferences.forecastsKey) private var showForecasts = SourcePreferences.forecastsEnabledByDefault
    let selector: ProcessSelector

    private let labels: [ProcessSelector: String] = [
        .covid(.incidence): "Weekly Incidence",
        .covid(.cases): "Cases",
        .covid(.deaths): "Deaths",
        .covid(.recovered): "Recovered"
    ]

    /// The forecast after the last measurement, while forecasts are switched on.
    private var forecast: ProcessForecast? {
        return self.showForecasts ? presenter.forecasts[self.selector] : nil
    }

    var body: some View {
        VStack {
            HStack(alignment: .bottom) {
                Text("\(self.presenter.name) \(self.labels[selector] ?? "<Unknown>")")
                Spacer()
                if let forecast = self.forecast {
                    ForecastLegend(origin: forecast.origin, color: Color.chart)
                }
            }
            Chart {
                ForEach(presenter.measurements[selector] ?? []) { measurement in
                    LineMark(
                        x: .value("Date", measurement.timestamp),
                        y: .value("Value", measurement.value.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(.gray.opacity(0.0))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    AreaMark(
                        x: .value("Date", measurement.timestamp),
                        y: .value("Value", measurement.value.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Gradient.linear)
                }

                if let forecast = self.forecast {
                    ForecastMarks(
                        forecast: forecast, anchor: presenter.measurements[selector]?.last, color: Color.chart, xLabel: "Date", yLabel: "Value")
                }

                if let measurement = presenter.current[selector] {
                    RuleMark(x: .value("Date", measurement.timestamp))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                    PointMark(
                        x: .value("Date", measurement.timestamp),
                        y: .value("Value", measurement.value.value)
                    )
                    .symbolSize(CGSize(width: 7, height: 7))
                    .annotation(position: .topTrailing, spacing: 0, overflowResolution: .init(x: .fit, y: .fit)) {
                        VStack {
                            Text(measurement.timestamp.absoluteString())
                                .font(.footnote)
                            HStack {
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
                        RuleMark(x: .value("Date", timestamp))
                            .lineStyle(StrokeStyle(lineWidth: 1))
                        PointMark(
                            x: .value("Date", timestamp),
                            y: .value("Value", measurement.value.value)
                        )
                        .symbolSize(CGSize(width: 7, height: 7))
                        .annotation(position: .bottomLeading, spacing: 0, overflowResolution: .init(x: .fit, y: .fit)) {
                            VStack {
                                Text(timestamp.absoluteString())
                                    .font(.footnote)
                                HStack {
                                    Text(String(format: "%.1f%@", measurement.value.value, measurement.value.unit.symbol))
                                        .font(.headline)
                                }
                            }
                            .padding(7)
                            .padding(.horizontal, 7)
                            .quality(measurement.quality)
                        }
                    }
                    else if let forecast = self.forecast, let point = ForecastDisplay.point(at: timestamp, in: forecast) {
                        ForecastMarker(point: point, origin: forecast.origin, format: "%.1f%@", color: Color.accentColor, xLabel: "Date", yLabel: "Value")
                    }
                }
            }
            .chartYScale(domain: ForecastDisplay.domain(range: presenter.range[selector], forecast: self.forecast))
            .chartOverlay { geometryProxy in
                GeometryReader { geometryReader in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let horizontalAmount = abs(value.translation.width)
                                    let verticalAmount = abs(value.translation.height)
                                    if horizontalAmount > verticalAmount * 2.0 {
                                        if let plotFrame = geometryProxy.plotFrame {
                                            let x = value.location.x - geometryReader[plotFrame].origin.x
                                            if let source: Date = geometryProxy.value(atX: x) {
                                                if let target = Date.round(from: source, strategy: .lastDayChange) {
                                                    self.timestamp = target
                                                }
                                            }
                                        }
                                    }
                                }
                                .onEnded { value in
                                    self.timestamp = nil
                                }
                        )
                }
            }
        }
    }
}
