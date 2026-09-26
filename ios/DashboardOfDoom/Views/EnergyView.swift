import DoomKitProcess
import DoomKitLocation
import DoomKitTools
import Charts
import SwiftUI

/// The Energy tab: a chart per price. There is one sensor and it has no place, so the location row names the sources instead.
struct EnergyView: View {
    @ScaledMetric(relativeTo: .body) private var chartHeight = 167.0
    @Environment(EnergyPresenter.self) private var presenter

    var body: some View {
        VStack {
            if self.presenter.timestamp == nil {
                ActivityIndicator()
            }
            else {
                VStack(alignment: .leading) {
                    HStack {
                        Image(systemName: "globe.europe.africa")
                        Text(String(format: "%@", self.presenter.placemark))
                        Spacer()
                    }
                    .accentLabel()
                    HStack {
                        Text("Last update: \(Date.absoluteString(date: self.presenter.timestamp))")
                        Spacer()
                    }
                    .foregroundColor(.gray)
                }
                .font(.footnote)

                let selectors = ProcessSelector.Energy.allCases.filter { self.presenter.isAvailable(selector: .energy($0)) }
                ForEach(Array(selectors.enumerated()), id: \.element) { index, selector in
                    // A chart's fill fades to nothing at its axis, so without a line nothing marks where one section ends.
                    if index > 0 {
                        Divider()
                            .padding(.horizontal, 5)
                            .padding(.trailing, 5)
                    }
                    VStack {
                        VStack {
                            EnergyChartView(selector: .energy(selector))
                        }
                        .padding(.vertical, 5)
                        .frame(height: self.chartHeight)
                        // Inset like a card but without one: the room around the text is what keeps it apart from the chart's axis
                        // labels above and the next title below.
                        if let explainer = EnergyExplainers.text[.energy(selector)] {
                            HStack {
                                Text(explainer)
                                    .font(.footnote)
                                    .foregroundColor(.gray)
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.top, 2)
                            .padding(.bottom, 12)
                        }
                    }
                }
            }
        }
    }
}
