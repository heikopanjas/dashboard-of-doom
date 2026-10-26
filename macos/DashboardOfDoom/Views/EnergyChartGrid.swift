import DoomKitProcess
import SwiftUI

/// The charts of one reading's series, two to a row, each with its explainer under it. A series the reading does not have is left out.
struct EnergyChartGrid: View {
    let reading: ProcessReading
    let selectors: [ProcessSelector.Energy]

    var body: some View {
        let available = self.selectors.filter { self.reading.isAvailable(selector: .energy($0)) }
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 16) {
            ForEach(available, id: \.self) { selector in
                VStack(alignment: .leading) {
                    VStack {
                        EnergyChartView(reading: self.reading, selector: .energy(selector))
                    }
                    .frame(height: 167)
                    if let explainer = EnergyExplainers.text[.energy(selector)] {
                        Text(explainer)
                            .font(.footnote)
                            .foregroundColor(.gray)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }
}
