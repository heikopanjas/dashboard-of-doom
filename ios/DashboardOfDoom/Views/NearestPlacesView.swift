import DoomKitLocation
import SwiftUI

/// The closest place of each category. Reads every loaded point, so the map's
/// switches do not affect it. Renders nothing at all, not even its divider,
/// until something is loaded.
struct NearestPlacesView: View {
    @Environment(PointOfInterestPresenter.self) private var presenter
    @State private var userLocation = AppLocation.shared.state.location

    struct Place: Identifiable {
        let category: PointOfInterestCategory
        let point: PointOfInterest
        let distance: Double  // metres
        var id: String { return self.point.id }
    }

    static let categories: [PointOfInterestCategory] = [.pharmacies, .hospitals, .stores, .funeralDirectors, .cemeteries]

    /// The closest loaded point per category, in the order of `categories`.
    /// Categories without points are skipped.
    static func nearest(points: [PointOfInterest], from location: Location) -> [Place] {
        return Self.categories.compactMap { category in
            points
                .filter { $0.category == category }
                .map { Place(category: category, point: $0, distance: PointOfInterestPresenter.distance(location, $0.location)) }
                .min { $0.distance < $1.distance }
        }
    }

    /// Metric by hand, so the device locale cannot switch to miles.
    static func distanceString(_ metres: Double) -> String {
        return metres < 1000 ? String(format: "%.0f m", metres) : String(format: "%.1f km", metres / 1000)
    }

    static func singular(_ category: PointOfInterestCategory) -> String {
        switch category {
            case .pharmacies: return "Pharmacy"
            case .hospitals: return "Hospital"
            case .stores: return "Store"
            case .funeralDirectors: return "Funeral director"
            case .cemeteries: return "Cemetery"
        }
    }

    private var places: [Place] {
        return Self.nearest(points: self.presenter.allPoints, from: self.userLocation)
    }

    var body: some View {
        let places = self.places
        if places.isEmpty == false {
            VStack {
                // Same modifiers as the dividers ContentView puts between the other home rows.
                Divider()
                    .padding(.horizontal, 5)
                    .padding(.trailing, 5)
                VStack {
                    HStack {
                        Text("Nearest places")
                        Spacer()
                    }
                    .font(.headline)
                    .accentLabel()
                    ForEach(places) { place in
                        HStack(spacing: 6) {
                            Image(systemName: place.category.symbol)
                                .foregroundStyle(place.category.color)
                                .frame(width: 22)
                                .accessibilityHidden(true)
                            Text(place.point.name ?? Self.singular(place.category))
                                .lineLimit(1)
                            Spacer()
                            Text(Self.distanceString(place.distance))
                                .font(.footnote)
                                .foregroundColor(.gray)
                                .monospacedDigit()
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(
                            "\(Self.singular(place.category)), \(place.point.name ?? "unnamed"), \(Self.distanceString(place.distance))"
                        )
                    }
                }
                .padding(5)
                .padding(.trailing, 3)
            }
            .task {
                // Observes only; never starts tracking. Same footprint as MapView.
                for await state in AppLocation.shared.updates() {
                    guard Task.isCancelled == false else { return }
                    self.userLocation = state.location
                }
            }
        }
    }
}
