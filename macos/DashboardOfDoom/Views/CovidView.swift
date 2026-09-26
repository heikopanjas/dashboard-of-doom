import DoomKitProcess
import Charts
import SwiftUI

struct CovidView: View {
    @Environment(CovidPresenter.self) private var presenter

    var body: some View {
        // Map, header and charts scroll together, as on the Level and Energy tabs.
        ScrollView {
            VStack(alignment: .leading) {
                // The reporting district: its outline, the incidence at its centroid and the reader's dot. It draws nothing until loaded.
                CovidMapView()
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

                    let selectors = ProcessSelector.Covid.allCases.filter {
                        self.presenter.isAvailable(selector: .covid($0))
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(selectors, id: \.self) { selector in
                            VStack {
                                CovidChartView(selector: .covid(selector))
                            }
                            .frame(height: 167)
                        }
                    }
                }
            }
        }
    }
}
