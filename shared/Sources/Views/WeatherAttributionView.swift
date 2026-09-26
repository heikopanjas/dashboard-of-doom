import DoomKitTools
import SwiftUI
import WeatherKit

/// The Apple Weather mark and the link to Apple's page of other data sources, which WeatherKit requires wherever its data is shown. Both
/// come from WeatherKit at run time, so they stay what Apple currently asks for; until they load the row shows the service name as text.
struct WeatherAttributionView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var attribution: WeatherAttribution?

    var body: some View {
        HStack(spacing: 8) {
            if let attribution {
                AsyncImage(url: self.colorScheme == .dark ? attribution.combinedMarkDarkURL : attribution.combinedMarkLightURL) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    Text(attribution.serviceName)
                }
                .frame(height: 12)
                .accessibilityLabel(attribution.serviceName)
                Link("Other data sources", destination: attribution.legalPageURL)
            }
            else {
                Text("Weather: Apple Weather")
            }
            Spacer()
        }
        .font(.footnote)
        .foregroundColor(.gray)
        .task {
            do {
                self.attribution = try await WeatherService.shared.attribution
            }
            catch {
                trace.error("Loading the Apple Weather attribution failed: %@", error.localizedDescription)
            }
        }
    }
}
