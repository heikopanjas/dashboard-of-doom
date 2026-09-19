import DoomKitProcess
import DoomKitLocation
import DoomKitTools
import Charts
import SwiftUI

struct ForecastView: View {
    @ScaledMetric(relativeTo: .body) private var chartHeight = 167.0
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
                    .accentLabel()
                    HStack {
                        Text("Last update: \(Date.absoluteString(date: self.presenter.timestamp))")
                        Spacer()
                    }
                    .foregroundColor(.gray)
                }
                .font(.footnote)
                #endif

                ForEach(ProcessSelector.Forecast.allCases, id: \.self) { selector in
                    if self.presenter.isAvailable(selector: .forecast(selector)) {
                        VStack {
                            ForecastChartView(selector: .forecast(selector))
                        }
                        .padding(.vertical, 5)
                        .frame(height: self.chartHeight)
                    }
                }
            }
        }
    }
}
