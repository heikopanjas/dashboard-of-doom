import DoomKitProcess
import Charts
import SwiftUI

/// The Energy tab: the fuel station map, then a chart per price. There is one price sensor and it has no place, so the location row names
/// the sources instead.
struct EnergyView: View {
    @Environment(EnergyPresenter.self) private var presenter

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                // Renders nothing until a Tankerkoenig key is stored and stations have loaded.
                FuelMapView()

                if self.presenter.timestamp == nil {
                    ActivityIndicator()
                }
                else {
                    HStack(alignment: .bottom) {
                        HStack {
                            Image(systemName: "safari")
                            Text(String(format: "%@", self.presenter.placemark))
                        }
                        Spacer()
                        Text("Last update: \(Date.absoluteString(date: self.presenter.timestamp))")
                            .foregroundColor(.gray)
                    }
                    .font(.footnote)

                    let selectors = ProcessSelector.Energy.allCases.filter { self.presenter.isAvailable(selector: .energy($0)) }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 16) {
                        ForEach(selectors, id: \.self) { selector in
                            VStack(alignment: .leading) {
                                VStack {
                                    EnergyChartView(selector: .energy(selector))
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
        }
    }
}
