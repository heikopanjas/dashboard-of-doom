import DoomKitProcess
import SwiftUI

/// The location row and the last-update row above one sensor's charts.
///
/// The nearest sensor shows its address, as it always has. The others have no address, since only the nearest is geocoded, so they show
/// the station name and how far away it is.
struct SensorHeaderView: View {
    let reading: ProcessReading
    let isNearest: Bool
    /// The color of the sensor's label on its map. With one, the location row is a pill in that color, like the label, so the
    /// chart below can be matched to its label. Without one the row is plain text.
    var color: Color? = nil

    var body: some View {
        VStack(alignment: .leading) {
            self.locationRow
            HStack {
                Text(Self.subtitle(for: self.reading, isNearest: self.isNearest))
                Spacer()
            }
            .foregroundColor(.gray)
        }
        .font(.footnote)
    }

    @ViewBuilder private var locationRow: some View {
        if let color = self.color {
            HStack {
                HStack {
                    Image(systemName: "safari")
                    Text(Self.title(for: self.reading, isNearest: self.isNearest))
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 10)
                // Half transparent, like the map label, so the pill and the label are the same tint.
                .background(RoundedRectangle(cornerRadius: 13).fill(color).opacity(0.5))
                .foregroundStyle(.black)
                Spacer()
            }
        }
        else {
            HStack {
                Image(systemName: "safari")
                Text(Self.title(for: self.reading, isNearest: self.isNearest))
                Spacer()
            }
            .accentLabel()
        }
    }

    static func title(for reading: ProcessReading, isNearest: Bool) -> String {
        return SensorLabels.title(for: reading, isNearest: isNearest)
    }

    static func subtitle(for reading: ProcessReading, isNearest: Bool) -> String {
        return SensorLabels.subtitle(for: reading, isNearest: isNearest)
    }

    static func displayName(_ text: String) -> String {
        return SensorLabels.displayName(text)
    }
}
