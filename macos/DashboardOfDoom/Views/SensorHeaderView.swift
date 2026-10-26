import DoomKitProcess
import SwiftUI

/// The name row and the last-update row above one sensor's charts. The name row is a pill in the color of the sensor's map label, since
/// the color is the only link between a label and its chart; the words come from `SensorLabels`, as on iOS.
struct SensorHeaderView: View {
    let reading: ProcessReading
    let isNearest: Bool
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                HStack {
                    Image(systemName: "safari")
                    Text(SensorLabels.title(for: self.reading, isNearest: self.isNearest))
                        .lineLimit(1)
                }
                .padding(.vertical, 3)
                .padding(.horizontal, 9)
                // Half transparent, like the map label, so the pill and the label are the same tint.
                .background(RoundedRectangle(cornerRadius: 11).fill(self.color).opacity(0.5))
                .foregroundStyle(.black)
                Spacer()
            }
            Text(SensorLabels.subtitle(for: self.reading, isNearest: self.isNearest))
                .foregroundColor(.gray)
                .lineLimit(1)
        }
        .font(.footnote)
    }
}

/// Level and radiation have one chart per sensor, so their sensors sit in a two-column grid of cards: the header, then the charts.
struct SensorCardGrid<Charts: View>: View {
    let readings: [ProcessReading]
    /// Picks the color list; the position of a reading picks the color, as on the map.
    let colorSelector: ProcessSelector
    @ViewBuilder let charts: (ProcessReading) -> Charts

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 20) {
            ForEach(Array(self.readings.enumerated()), id: \.element.id) { index, reading in
                VStack(alignment: .leading, spacing: 8) {
                    SensorHeaderView(
                        reading: reading, isNearest: index == 0, color: Color.sensor(selector: self.colorSelector, index: index))
                    self.charts(reading)
                }
            }
        }
    }
}
