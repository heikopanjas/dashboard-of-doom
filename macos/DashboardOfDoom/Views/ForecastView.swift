import DoomKitProcess
import Charts
import SwiftUI

struct ForecastView: View {
    @Environment(ForecastPresenter.self) private var presenter

    var body: some View {
        VStack {
            if self.presenter.timestamp == nil {
                ActivityIndicator()
            }
            else {
#if os(macOS)
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
#else
                VStack(alignment: .leading) {
                    HStack {
                        Image(systemName: "safari")
                        Text(String(format: "%@", self.presenter.placemark))
                        Spacer()
                    }
                    .foregroundColor(.accentColor)
                    HStack {
                        Text("Last update: \(Date.absoluteString(date: self.presenter.timestamp))")
                        Spacer()
                    }
                    .foregroundColor(.gray)
                }
                .font(.footnote)
#endif

                let selectors = ProcessSelector.Forecast.allCases.filter {
                    self.presenter.isAvailable(selector: .forecast($0), treshold: self.computeThreshold(selector: $0))
                }

                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(selectors, id: \.self) { selector in
                            VStack {
                                ForecastChartView(selector: .forecast(selector))
                            }
                            .frame(height: 167)
                        }
                    }
                    // WeatherKit requires the Apple Weather mark and its legal link wherever its data is shown.
                    WeatherAttributionView()
                        .padding(.top, 8)
                }
            }
        }

    }

    func computeThreshold(selector: ProcessSelector.Forecast) -> Double {
        if selector == .temperature || selector == .apparentTemperature || selector == .dewPoint  {
            return -33.0
        }
        return 0.0
    }
}
