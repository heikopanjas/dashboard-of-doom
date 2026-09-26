import DoomKitProcess
import Charts
import SwiftUI

struct EnergyChartView: View {
    @Environment(EnergyPresenter.self) private var presenter
    @State private var timestamp: Date?
    let selector: ProcessSelector

    private let labels: [ProcessSelector: String] = [
        .energy(.brent): "Brent Crude",
        .energy(.wti): "WTI Crude",
        .energy(.lng): "EU LNG"
    ]

    var body: some View {
        VStack {
            HStack(alignment: .bottom) {
                Text(self.labels[selector] ?? "<Unknown>")
                Spacer()
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
                    // Anchored at the floor of the range, not at zero: the axis starts near the prices, and an area from zero would be
                    // painted far below the plot, behind whatever comes after the chart.
                    AreaMark(
                        x: .value("Date", measurement.timestamp),
                        yStart: .value("Floor", presenter.range[selector]?.lowerBound ?? 0.0),
                        yEnd: .value("Value", measurement.value.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Gradient.linear)
                }

                if let measurement = presenter.current[selector] {
                    RuleMark(x: .value("Date", measurement.timestamp))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                    PointMark(
                        x: .value("Date", measurement.timestamp),
                        y: .value("Value", measurement.value.value)
                    )
                    .symbolSize(CGSize(width: 7, height: 7))
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
                }
            }
            .chartYScale(domain: presenter.range[selector] ?? 0.0 ... 0.0)
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
