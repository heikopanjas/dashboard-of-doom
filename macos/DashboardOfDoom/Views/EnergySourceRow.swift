import SwiftUI

/// The sources of a screen's series and when they were last fetched, above its charts.
struct EnergySourceRow: View {
    let placemark: String?
    let timestamp: Date?

    var body: some View {
        HStack(alignment: .bottom) {
            HStack {
                Image(systemName: "safari")
                Text(self.placemark ?? "")
            }
            Spacer()
            Text("Last update: \(Date.absoluteString(date: self.timestamp))")
                .foregroundColor(.gray)
        }
        .font(.footnote)
    }
}
