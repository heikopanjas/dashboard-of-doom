import DoomKitProcess
import DoomKitLocation
import DoomKitTools
import Charts
import SwiftUI

struct ParticleView: View {
    @ScaledMetric(relativeTo: .body) private var chartHeight = 167.0
    @Environment(ParticlePresenter.self) private var presenter

    var body: some View {
        VStack {
            if self.presenter.sensor?.timestamp == nil {
                ActivityIndicator()
            }
            else {
                #if os(macOS)
                HStack(alignment: .bottom) {
                    HStack {
                        Image(systemName: "safari")
                        Text(String(format: "%@", self.presenter.sensor?.placemark ?? "<Unknown>"))
                    }
                    Spacer()
                    Text("Last update: \(Date.absoluteString(date: self.presenter.sensor?.timestamp))")
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
                
                ForEach(ProcessSelector.Particle.allCases, id: \.self) { selector in
                    if self.presenter.isAvailable(selector: .particle(selector)) {
                        VStack {
                            ParticleChartView(selector: .particle(selector))
                        }
                        .padding(.vertical, 5)
                        .frame(height: self.chartHeight)
                    }
                }
            }
        }
    }
}
