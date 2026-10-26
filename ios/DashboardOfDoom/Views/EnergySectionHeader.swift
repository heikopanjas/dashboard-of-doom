import SwiftUI

/// A section's title above its charts, with where the data comes from and when it was last fetched.
struct EnergySectionHeader: View {
    let title: String
    let symbol: String
    let placemark: String?
    let timestamp: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: self.symbol)
                Text(self.title)
                Spacer()
            }
            .font(.headline)
            .accentLabel()
            VStack(alignment: .leading) {
                HStack {
                    Image(systemName: "globe.europe.africa")
                    Text(self.placemark ?? "")
                    Spacer()
                }
                HStack {
                    Text("Last update: \(Date.absoluteString(date: self.timestamp))")
                    Spacer()
                }
            }
            .font(.footnote)
            .foregroundColor(.gray)
        }
        .padding(.bottom, 4)
    }
}
