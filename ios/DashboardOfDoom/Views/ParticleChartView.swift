import DoomKitProcess
import DoomKitLocation
import DoomKitTools
import Charts
import SwiftUI

struct ParticleChartView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var timestamp: Date?
    let selector: ProcessSelector
    let reading: ProcessReading

    enum ParticleSymbol: String, CaseIterable {
        case pm10 = "\u{1D40F}\u{1D40C}\u{2081}\u{2080}"  // PM10, Particulate matter < 10µm
        case co = "\u{1D402}\u{1D40E}"  // CO, Carbon monoxide
        case o3 = "\u{1D40E}\u{2083}"  // O3, Ozone
        case so2 = "\u{1D412}\u{1D40E}\u{2082}"  // SO2, Sulfur dioxide
        case no2 = "\u{1D40D}\u{1D40E}\u{2082}"  // NO2, Nitrogen dioxide
        case lead = "\u{1D40F}\u{1D41B}"  // Pb, Lead in particulate matter < 10µm
        case benzoapyrene = "\u{1D402}\u{2082}\u{2080}\u{1D407}\u{2081}\u{2082}"  // C20H12, Benzo(a)pyrene in particulate matter < 10µm
        case benzene = "\u{1D402}\u{2086}\u{1D407}\u{2086}"  // C6H6, Benzene
        case pm25 = "\u{1D40F}\u{1D40C}\u{2082}\u{2085}"  // Particulate matter < 2.5µm
        case arsenic = "\u{1D400}\u{1D42C}"  // As, Arsenic in particulate matter < 10µm
        case cadmium = "\u{1D402}\u{1D41D}"  // Cd, Cadmium in particulate matter < 10µm
        case nickel = "\u{1D40D}\u{1D422}"  // Ni, Nickel in particulate matter < 10µm
    }

    private let symbols: [ProcessSelector: ParticleSymbol] = [
        .particle(.pm10): .pm10,
        .particle(.pm25): .pm25,
        .particle(.o3): .o3,
        .particle(.no2): .no2,
        .particle(.co): .co,
        .particle(.so2): .so2,
        .particle(.lead): .lead,
        .particle(.benzoapyrene): .benzoapyrene,
        .particle(.benzene): .benzene,
        .particle(.arsenic): .arsenic,
        .particle(.cadmium): .cadmium,
        .particle(.nickel): .nickel
    ]

    var body: some View {
        VStack {
            HStack(alignment: .bottom) {
                Text("\((symbols[selector] ?? .pm10).rawValue)")
                Spacer()
            }
            .font(.headline)
            .accentLabel()
            Chart {
                ForEach(self.reading.measurements[selector] ?? []) { measurement in
//                    if selector == .particle(.pm10) {
//                        LineMark(
//                            x: .value("Date", measurement.timestamp),
//                            y: .value("Particle", 40.0)
//                        )
//                        .interpolationMethod(.linear)
//                        .foregroundStyle(Color.treshold)
//                        .lineStyle(StrokeStyle(lineWidth: 1))
//                    }
//                    else if selector == .particle(.pm25) {
//                        LineMark(
//                            x: .value("Date", measurement.timestamp),
//                            y: .value("Particle", 25.0)
//                        )
//                        .interpolationMethod(.linear)
//                        .foregroundStyle(Color.treshold)
//                        .lineStyle(StrokeStyle(lineWidth: 1))
//                    }
//                    else if selector == .particle(.no2) {
//                        LineMark(
//                            x: .value("Date", measurement.timestamp),
//                            y: .value("Particle", 40.0)
//                        )
//                        .interpolationMethod(.linear)
//                        .foregroundStyle(Color.treshold)
//                        .lineStyle(StrokeStyle(lineWidth: 1))
//                    }
                    AreaMark(
                        x: .value("Date", Date.round(from: measurement.timestamp, strategy: .previousHour) ?? Date.now),
                        yStart: .value("Particle", self.reading.range[selector]?.lowerBound ?? 0.0),
                        yEnd: .value("Particle", measurement.value.value)
                    )
                    .interpolationMethod(.catmullRom(alpha: 0.33))
                    .foregroundStyle(Gradient.linear)
                }

                if let measurement = self.reading.current[selector] {
                    RuleMark(x: .value("Date", measurement.timestamp))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                        .foregroundStyle(self.colorScheme.markerColor)
                    PointMark(
                        x: .value("Date", measurement.timestamp),
                        y: .value("Particle", measurement.value.value)
                    )
                    .symbolSize(CGSize(width: 7, height: 7))
                    .foregroundStyle(self.colorScheme.markerColor)
                    .annotation(position: .topLeading, spacing: 0, overflowResolution: .init(x: .fit, y: .fit)) {
                        VStack {
                            Text(measurement.timestamp.absoluteString())
                                .font(.footnote)
                            HStack {
                                Text(String(format: "%.0f%@", measurement.value.value, measurement.value.unit.symbol))
                                if let icon = self.reading.trend[selector] {
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
                    if let measurement = self.reading.measurements[selector]?.first(where: { $0.timestamp == timestamp }) {
                        RuleMark(x: .value("Date", Date.round(from: timestamp, strategy: .previousHour) ?? Date.now))
                            .lineStyle(StrokeStyle(lineWidth: 1))
                            .foregroundStyle(self.colorScheme.markerColor)
                        PointMark(
                            x: .value("Date", timestamp),
                            y: .value("Particle", measurement.value.value)
                        )
                        .symbolSize(CGSize(width: 7, height: 7))
                        .foregroundStyle(self.colorScheme.markerColor)
                        .annotation(position: .bottomTrailing, spacing: 0, overflowResolution: .init(x: .fit, y: .fit)) {
                            VStack {
                                Text(timestamp.absoluteString())
                                    .font(.footnote)
                                HStack {
                                    Text(String(format: "%.0f%@", measurement.value.value, measurement.value.unit.symbol))
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
            .chartYScale(domain: self.reading.range[selector] ?? 0.0 ... 0.0)
            .chartInteractiveOverlay(timestamp: $timestamp, roundingStrategy: .previousHour)
        }
    }
}

