import Charts
import DoomKitProcess
import SwiftUI

struct SurveyView: View {
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
                    .foregroundColor(.accentColor)
                    HStack {
                        Text("Last update: \(Date.absoluteString(date: self.presenter.timestamp))")
                        Spacer()
                    }
                    .foregroundColor(.gray)
                }
                .font(.footnote)
                #endif

                let selectors = ProcessSelector.Survey.allCases.filter {
                    self.presenter.isAvailable(selector: .survey($0), treshold: 5.0)
                }

                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(selectors, id: \.self) { selector in
                            VStack {
                                SurveyChartView(selector: .survey(selector))
                            }
                            .frame(height: 167)
                        }
                    }
                }
            }
        }
    }
}
