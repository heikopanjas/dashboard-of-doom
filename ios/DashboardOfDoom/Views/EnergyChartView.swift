import Charts
import DoomKitLocation
import DoomKitProcess
import DoomKitTools
import SwiftUI

/// One energy series as a chart: a price, a fuel stock or a country's production, read from its reading.
struct EnergyChartView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var timestamp: Date?
    @AppStorage(ForecastFamily.energy.key) private var showForecasts = ForecastFamily.enabledByDefault
    /// The series' reading: the prices' or the stocks' one sensor, or one producing country.
    let reading: ProcessReading
    let selector: ProcessSelector

    /// The forecast after the last measurement, while forecasts are switched on.
    private var forecast: ProcessForecast? {
        return self.showForecasts ? self.reading.forecasts[self.selector] : nil
    }

    var body: some View {
        VStack {
            HStack(alignment: .bottom) {
                if EnergyDisplay.title(for: self.selector).isEmpty == false {
                    Text(EnergyDisplay.title(for: self.selector))
                }
                if let status = EnergyDisplay.status(in: self.reading.measurements[selector] ?? []) {
                    StockStatusBadge(status: status, period: EnergyDisplay.statusPeriod(in: self.reading.measurements[selector] ?? []))
                }
                Spacer()
                if let forecast = self.forecast {
                    ForecastLegend(origin: forecast.origin, color: Color.chart)
                }
            }
            .font(.headline)
            .accentLabel()
            Chart {
                ForEach(self.reading.measurements[selector] ?? []) { measurement in
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
                        yStart: .value("Floor", ForecastDisplay.domain(range: self.reading.range[selector], forecast: self.forecast).lowerBound),
                        yEnd: .value("Value", measurement.value.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Gradient.linear)
                }

                if let forecast = self.forecast {
                    ForecastMarks(
                        forecast: forecast, anchor: self.reading.measurements[selector]?.last, color: Color.chart, colorScheme: self.colorScheme,
                        xLabel: "Date", yLabel: "Value")
                }

                // The level EuroOilWatch holds a stock against; the chart's range always holds it.
                if let minimum = EnergyDisplay.minimumDays(in: self.reading.measurements[selector] ?? []) {
                    RuleMark(y: .value("Minimum", minimum))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                        .foregroundStyle(Color.stockMinimum)
                        .annotation(position: .bottom, alignment: .leading, spacing: 1) {
                            Text(String(format: "Minimum %.0f days", minimum))
                                .font(.caption2)
                                .foregroundStyle(Color.stockMinimum)
                        }
                }

                if let measurement = self.reading.current[selector] {
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
                            Text(EnergyDisplay.dateText(measurement.timestamp, for: self.selector))
                                .font(.footnote)
                            HStack {
                                Text(EnergyDisplay.valueText(measurement, for: self.selector))
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
                    if let measurement = EnergyDisplay.measurement(at: timestamp, in: self.reading.measurements[selector] ?? []) {
                        RuleMark(x: .value("Date", measurement.timestamp))
                            .lineStyle(StrokeStyle(lineWidth: 1))
                            .foregroundStyle(self.colorScheme.markerColor)
                        PointMark(
                            x: .value("Date", measurement.timestamp),
                            y: .value("Value", measurement.value.value)
                        )
                        .symbolSize(CGSize(width: 7, height: 7))
                        .foregroundStyle(self.colorScheme.markerColor)
                        .annotation(position: .bottomLeading, spacing: 0, overflowResolution: .init(x: .fit, y: .fit)) {
                            VStack {
                                Text(EnergyDisplay.dateText(measurement.timestamp, for: self.selector))
                                    .font(.footnote)
                                HStack {
                                    Text(EnergyDisplay.valueText(measurement, for: self.selector))
                                        .font(.headline)
                                }
                            }
                            .padding(7)
                            .padding(.horizontal, 7)
                            .quality(measurement.quality)
                        }
                    }
                    else if let forecast = self.forecast, let point = ForecastDisplay.point(at: timestamp, in: forecast) {
                        ForecastMarker(
                            point: point, origin: forecast.origin, format: EnergyDisplay.format(for: self.selector),
                            color: self.colorScheme.markerColor, xLabel: "Date",
                            yLabel: "Value")
                    }
                }
            }
            .chartYScale(domain: ForecastDisplay.domain(range: self.reading.range[selector], forecast: self.forecast))
            .chartInteractiveOverlay(timestamp: $timestamp, roundingStrategy: .lastDayChange)
        }
    }
}
