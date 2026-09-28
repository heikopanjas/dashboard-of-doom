import DoomKitProcess
import Charts
import SwiftUI

struct SurveyChartView: View {
    @Environment(SurveyPresenter.self) private var presenter
    @State private var timestamp: Date?
    @AppStorage(ForecastFamily.polls.key) private var showForecasts = ForecastFamily.enabledByDefault
    let selector: ProcessSelector

    private let shortLabels: [ProcessSelector: String] = [
        .survey(.fascists): "Fascists",
        .survey(.clowns): "Clowns",
        .survey(.linke): "Linke",
        .survey(.gruene): "Grüne",
        .survey(.spd): "SPD",
        .survey(.afd): "AfD",
        .survey(.fdp): "FDP",
        .survey(.bsw): "BSW",
        .survey(.cducsu): "CDU/CSU",
        .survey(.cdu): "CDU",
        .survey(.csu): "CSU",
        .survey(.sonstige): "Sonstige",
        .survey(.piraten): "Piraten",
        .survey(.freie_waehler): "Freie Wähler",
        .survey(.npd): "NPD",
        .survey(.ssw): "SSW",
        .survey(.bayernpartei): "Bayernpartei",
        .survey(.oedp): "ÖDP",
        .survey(.partei): "Die PARTEI",
        .survey(.bvb_fw): "BVB/FW",
        .survey(.tierschutz): "Tierschutzpartei",
        .survey(.biw): "BIW",
        .survey(.familie): "Familie",
        .survey(.volt): "Volt",
        .survey(.bunt_saar): "bunt.saar",
        .survey(.bfth): "BfTh",
        .survey(.plus_brandenburg): "Plus Brandenburg",
        .survey(.werte_union): "WerteUnion"
    ]

    private let fullLabels: [ProcessSelector: String] = [
        .survey(.fascists): "Fascists",
        .survey(.clowns): "Clowns",
        .survey(.linke): "Die Linke",
        .survey(.gruene): "Bündnis 90/Die Grünen",
        .survey(.spd): "Sozialdemokratische Partei Deutschlands",
        .survey(.afd): "Alternative für Deutschland",
        .survey(.fdp): "Freie Demokratische Partei",
        .survey(.bsw): "Bündnis Sahra Wagenknecht",
        .survey(.cducsu): "Christlich Demokratische Union/Christlich-Soziale Union",
        .survey(.cdu): "Christlich Demokratische Union",
        .survey(.csu): "Christlich-Soziale Union",
        .survey(.sonstige): "Sonstige",
        .survey(.piraten): "Piratenpartei",
        .survey(.freie_waehler): "Freie Wähler",
        .survey(.npd): "Nationaldemokratische Partei Deutschlands",
        .survey(.ssw): "Südschleswigscher Wählerverband",
        .survey(.bayernpartei): "Bayernpartei e.V.",
        .survey(.oedp): "Ökologisch-Demokratische Partei",
        .survey(.partei): "Partei für Arbeit, Rechtsstaat, Tierschutz, Elitenförderung und basisdemokratische Initiative",
        .survey(.bvb_fw): "Brandenburger Vereinigte Bürgerbewegungen/Freie Wähler",
        .survey(.tierschutz): "Partei Mensch Umwelt Tierschutz",
        .survey(.biw): "Bürger in Wut",
        .survey(.familie): "Familienpartei Deutschlands",
        .survey(.volt): "Volt Deutschland",
        .survey(.bunt_saar): "bunt.saar - sozial-ökologische liste",
        .survey(.bfth): "Bürger für Thüringen",
        .survey(.plus_brandenburg): "Plus Brandenburg (Listenvereinigung aus Piratenpartei, ÖDP und Volt)",
        .survey(.werte_union): "WerteUnion"
    ]

    /// The forecast after the last measurement, while forecasts are switched on.
    private var forecast: ProcessForecast? {
        return self.showForecasts ? presenter.forecasts[self.selector] : nil
    }

    var body: some View {
        VStack {
            HStack(alignment: .bottom) {
                // No spacer inside: the row's own spacer pushes the forecast legend right, and a second one here left it no room.
                VStack(alignment: .leading) {
                    Text("\(self.shortLabels[selector] ?? String(format: "%d <Unknown>", selector.rawValue))")
                    if selector != .survey(.fascists) && selector != .survey(.clowns) && selector != .survey(.sonstige) {
                        #if os(iOS)
                        Text("\(String.truncate(self.fullLabels[selector], maxLength: 53) ?? String(format: "%d <Unknown>", selector.rawValue))")
                            .font(.footnote)
                            .foregroundColor(.gray)
                        #else
                        Text("\(self.fullLabels[selector] ?? String(format: "%d <Unknown>", selector.rawValue))")
                            .font(.callout)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        #endif
                    }
                }
                Spacer()
                if let forecast = self.forecast {
                    ForecastLegend(origin: forecast.origin, color: self.presenter.color(selector: self.selector))
                }
            }
            Chart {
                ForEach(presenter.measurements[selector] ?? []) { measurement in
                    if selector != .survey(.fascists) && selector != .survey(.clowns) && selector != .survey(.sonstige) {
                        LineMark(
                            x: .value("Timestamp", measurement.timestamp),
                            y: .value("Value", 5.0)
                        )
                        .interpolationMethod(.catmullRom)
//                        .foregroundStyle(Color.treshold)
                        .foregroundStyle(Color.red.opacity(0.67))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                    }
                    AreaMark(
                        x: .value("Timestamp", measurement.timestamp),
                        y: .value("Value", measurement.value.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(presenter.gradient(selector: selector))
                }

                if let forecast = self.forecast {
                    ForecastMarks(
                        forecast: forecast, anchor: presenter.measurements[selector]?.last, color: self.presenter.color(selector: self.selector), xLabel: "Timestamp", yLabel: "Value")
                }

                if let measurement = presenter.current[selector] {
                    RuleMark(x: .value("Timestamp", measurement.timestamp))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                    PointMark(
                        x: .value("Timestamp", measurement.timestamp),
                        y: .value("Value", measurement.value.value)
                    )
                    .symbolSize(CGSize(width: 7, height: 7))
                    .annotation(position: .topLeading, spacing: 0, overflowResolution: .init(x: .fit, y: .fit)) {
                        VStack {
                            Text(String(format: "%@ %@", measurement.timestamp.dateString(), measurement.timestamp.timeString()))
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

                if let timestamp = timestamp {
                    if let measurement = presenter.measurements[selector]?.first(where: { $0.timestamp == timestamp }) {
                        RuleMark(x: .value("Timestamp", timestamp))
                            .lineStyle(StrokeStyle(lineWidth: 1))
                        PointMark(
                            x: .value("Timestamp", timestamp),
                            y: .value("Value", measurement.value.value)
                        )
                        .symbolSize(CGSize(width: 7, height: 7))
                        .annotation(position: .bottomLeading, spacing: 0, overflowResolution: .init(x: .fit, y: .fit)) {
                            VStack {
                                Text(String(format: "%@ %@", timestamp.dateString(), timestamp.timeString()))
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
                        ForecastMarker(point: point, origin: forecast.origin, format: "%.1f%@", color: Color.accentColor, xLabel: "Timestamp", yLabel: "Value")
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
                                                if let target = Date.round(from: source, strategy: .lastUTCDayChange) {
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
