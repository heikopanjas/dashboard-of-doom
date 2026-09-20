import DoomKitProcess
import SwiftUI

/// The location row and the last-update row above one sensor's charts.
///
/// The nearest sensor shows its address, as it always has. The others have no address, since only the nearest is geocoded, so they show
/// the station name and how far away it is.
struct SensorHeaderView: View {
    let reading: ProcessReading
    let isNearest: Bool
    /// The color of the sensor's label on the Environment map. With one, the location row is a pill in that color, like the label, so the
    /// chart below can be matched to its label. Without one the row is plain text, as on the Particles tab.
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
        if isNearest == true {
            return reading.sensor.placemark ?? "<Unknown>"
        }
        // A level sensor is named after its waterway, which all of its neighbours share, so the gauge name is carried separately.
        let name = (reading.sensor.customData?["station"] as? String) ?? reading.sensor.name
        return Self.displayName(name)
    }

    static func subtitle(for reading: ProcessReading, isNearest: Bool) -> String {
        let update = "Last update: \(Date.absoluteString(date: reading.sensor.timestamp))"
        if isNearest == false, let distance = reading.sensor.distance {
            return "\(NearestPlacesView.distanceString(distance)) away · \(update)"
        }
        return update
    }

    /// PEGELONLINE writes names in capitals, such as `BERLIN-MÜHLENDAMM UP`. Words written that way are capitalized, except a short last
    /// word, which is a gauge suffix (`UP`, `OP`) and stays. Words that already have lower case letters are left alone.
    static func displayName(_ text: String) -> String {
        var tokens: [(text: String, isWord: Bool)] = []
        for character in text {
            let isWord = character.isLetter
            if let last = tokens.last, last.isWord == isWord {
                tokens[tokens.count - 1].text.append(character)
            }
            else {
                tokens.append((text: String(character), isWord: isWord))
            }
        }
        let lastWord = tokens.lastIndex(where: { $0.isWord })
        return tokens.enumerated().map { index, token in
            if token.isWord == false || token.text != token.text.uppercased() {
                return token.text
            }
            if token.text.count <= 2 && index == lastWord {
                return token.text
            }
            return String(token.text.prefix(1)) + token.text.dropFirst().lowercased()
        }.joined()
    }
}
