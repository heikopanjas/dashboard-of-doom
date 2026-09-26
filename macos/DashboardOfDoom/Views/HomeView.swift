import SwiftUI

/// The Home tab: the map, then the three rows the iOS home screen has under it, the next 24 hours, the current conditions and the nearest
/// places. The warnings card is left out, since macOS has a Warnings tab. The rows keep their own height and the map takes the rest, so
/// a taller window means a bigger map; the window's minimum height keeps it usable.
struct HomeView: View {
    var body: some View {
        VStack(spacing: 0) {
            MapView()
                .frame(minHeight: 260, maxHeight: .infinity)
            Divider()
            ForecastStripView()
                .padding(5)
            Divider()
                .padding(.horizontal, 5)
            CurrentConditionsView()
                .padding(5)
            // Draws its own leading divider, and nothing at all until places have loaded.
            NearestPlacesView()
        }
    }
}
