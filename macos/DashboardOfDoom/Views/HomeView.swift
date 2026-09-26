import SwiftUI

/// The Home tab, the iOS home screen in the dashboard popup: the map, then the next 24 hours, the current conditions, the nearest places
/// and, while the Warnings switch is on, the warnings. It scrolls, so the map has a fixed height and the rows below it keep theirs.
struct HomeView: View {
    @AppStorage(SourcePreferences.hazardsKey) private var showHazards: Bool = true

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                MapView()
                    .frame(height: 500)
                Divider()
                ForecastStripView()
                    .padding(5)
                Divider()
                    .padding(.horizontal, 5)
                CurrentConditionsView()
                    .padding(5)
                // Draws its own leading divider, and nothing at all until places have loaded.
                NearestPlacesView()
                if self.showHazards == true {
                    Divider()
                        .padding(.horizontal, 5)
                    HazardCardView()
                        .padding(5)
                }
            }
        }
    }
}
