import DoomKitProcess
import SwiftUI

/// The charts of one reading's series, one under the other with a divider between them, each with its explainer under it. A series the
/// reading does not have is left out.
struct EnergyChartList: View {
    @ScaledMetric(relativeTo: .body) private var chartHeight = 167.0
    let reading: ProcessReading
    let selectors: [ProcessSelector.Energy]

    var body: some View {
        let available = self.selectors.filter { self.reading.isAvailable(selector: .energy($0)) }
        ForEach(Array(available.enumerated()), id: \.element) { index, selector in
            // A chart's fill fades to nothing at its axis, so without a line nothing marks where one section ends.
            if index > 0 {
                Divider()
                    .padding(.horizontal, 5)
                    .padding(.trailing, 5)
            }
            VStack {
                VStack {
                    EnergyChartView(reading: self.reading, selector: .energy(selector))
                }
                .padding(.vertical, 5)
                .frame(height: self.chartHeight)
                // Inset like a card but without one: the room around the text is what keeps it apart from the chart's axis labels above
                // and the next title below.
                if let explainer = EnergyExplainers.text[.energy(selector)] {
                    EnergyExplainerText(text: explainer)
                }
            }
        }
    }
}
