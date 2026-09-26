import DoomKitProcess
import Foundation

/// The words above one sensor's charts, the same on both platforms.
///
/// The nearest sensor shows its address. The others have no address, since only the nearest is geocoded, so they show the station name
/// and how far away it is.
enum SensorLabels {
    static func title(for reading: ProcessReading, isNearest: Bool) -> String {
        if isNearest == true {
            return reading.sensor.placemark ?? "<Unknown>"
        }
        // Every source names its sensor after its station, level included, where that is the gauge.
        return Self.displayName(reading.sensor.name)
    }

    static func subtitle(for reading: ProcessReading, isNearest: Bool) -> String {
        let update = "Last update: \(Date.absoluteString(date: reading.sensor.timestamp))"
        if isNearest == false, let distance = reading.sensor.distance {
            return "\(Self.distanceString(distance)) away · \(update)"
        }
        return update
    }

    static func distanceString(_ metres: Double) -> String {
        return metres < 1000 ? String(format: "%.0f m", metres) : String(format: "%.1f km", metres / 1000)
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
