import DoomKitProcess
import SwiftUI

/// The parts of the current weather that the map pin does not show:
/// feels-like temperature, humidity, wind and pressure.
struct CurrentConditionsView: View {
    @Environment(WeatherPresenter.self) private var presenter
    @ScaledMetric(relativeTo: .callout) private var columnWidth = 150.0

    struct Item: Identifiable {
        let icon: String
        let title: String
        let value: String
        var id: String { return self.title }
    }

    /// One item per available series. A missing series drops its item; a missing
    /// gust drops only the suffix on the wind item.
    static func items(current: [ProcessSelector: ProcessValue<Dimension>]) -> [Item] {
        var items: [Item] = []
        if let feelsLike = current[.weather(.apparentTemperature)] {
            items.append(
                Item(icon: "thermometer.medium", title: "Feels like", value: Self.format(feelsLike.value, precision: 1)))
        }
        if let humidity = current[.weather(.humidity)] {
            items.append(Item(icon: "humidity", title: "Humidity", value: String(format: "%.0f%%", humidity.value.value)))
        }
        if let wind = current[.weather(.windSpeed)] {
            let speed = Self.speed(wind.value)
            var value = Self.format(speed, precision: 0)
            if let gust = current[.weather(.windGust)] {
                // One unit at the end, so the pair fits a grid cell on an iPhone.
                value = String(format: "%.0f, gusts %@", speed.value, Self.format(Self.speed(gust.value), precision: 0))
            }
            items.append(Item(icon: "wind", title: "Wind", value: value))
        }
        if let pressure = current[.weather(.pressure)] {
            items.append(
                Item(
                    icon: "gauge.with.dots.needle.33percent", title: "Pressure",
                    value: Self.format(Self.pressure(pressure.value), precision: 0)))
        }
        return items
    }

    static func speed(_ value: Measurement<Dimension>) -> Measurement<Dimension> {
        return value.unit is UnitSpeed ? value.converted(to: UnitSpeed.kilometersPerHour) : value
    }

    static func pressure(_ value: Measurement<Dimension>) -> Measurement<Dimension> {
        return value.unit is UnitPressure ? value.converted(to: UnitPressure.hectopascals) : value
    }

    /// No space before a degree or percent sign, a space before word symbols like km/h.
    static func format(_ value: Measurement<Dimension>, precision: Int) -> String {
        let symbol = value.unit.symbol
        let separator = symbol.hasPrefix("°") || symbol.hasPrefix("%") ? "" : " "
        return String(format: "%.\(precision)f%@%@", value.value, separator, symbol)
    }

    var body: some View {
        VStack {
            if self.presenter.timestamp == nil {
                ActivityIndicator()
            }
            else {
                HStack {
                    Image(systemName: self.presenter.icon)
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)
                    Text("Current conditions")
                    Spacer()
                }
                .font(.headline)
                .accentLabel()
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: self.columnWidth), alignment: .leading)],
                    alignment: .leading, spacing: 6
                ) {
                    ForEach(Self.items(current: self.presenter.current)) { item in
                        // Value under its title: adaptive columns can be narrow on iPad,
                        // where the grid packs as many minimum-width columns as fit.
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Image(systemName: item.icon)
                                    .foregroundStyle(Color.accentColor)
                                    .frame(width: 22)
                                    .accessibilityHidden(true)
                                Text(item.title)
                                    .font(.footnote)
                                    .foregroundColor(.gray)
                            }
                            Text(item.value)
                                .font(.callout)
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .padding(.leading, 28)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(item.title) \(item.value)")
                    }
                }
            }
        }
    }
}
