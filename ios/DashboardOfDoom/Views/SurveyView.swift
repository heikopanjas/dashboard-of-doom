import DoomKitProcess
import DoomKitLocation
import DoomKitTools
import Charts
import SwiftUI

struct SurveyView: View {
    @ScaledMetric(relativeTo: .body) private var chartHeight = 167.0
    @Environment(SurveyPresenter.self) private var presenter

    var body: some View {
        VStack {
            if presenter.timestamp == nil {
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
                
                ForEach(ProcessSelector.Survey.allCases, id: \.self) { selector in
                    if self.presenter.isAvailable(selector: .survey(selector)) {
                        VStack {
                            SurveyChartView(selector: .survey(selector))
                        }
                        .padding(.vertical, 5)
                        .frame(height: self.chartHeight)
                    }
                }
            }
        }
    }
}
