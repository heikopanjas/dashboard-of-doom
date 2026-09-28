import DoomKitLocation
import MapKit
import SwiftUI

/// The simulation window's content on macOS and the simulation sheet's on iOS: a search field, a map of Germany to pick a place on, and
/// Start. Start hands the place and its name to `onStart`, which makes the whole app behave as if the device were there.
struct SimulationView: View {
    /// Germany, for the search and as the limit of the camera.
    static let germany = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 51.15, longitude: 10.45), span: MKCoordinateSpan(latitudeDelta: 7.9, longitudeDelta: 9.3))

    let onStart: (Location, String?) -> Void
    @State private var search = SimulationSearch()
    @State private var selection = SimulationSelection()
    @State private var query = ""
    @State private var camera: MapCameraPosition
    @State private var visibleRect = MKMapRect.null
    @State private var mapSize = CGSize.zero
    @FocusState private var searching: Bool

    init(start: Location, onStart: @escaping (Location, String?) -> Void) {
        self.onStart = onStart
        self._camera = State(initialValue: .region(MKCoordinateRegion(center: start.coordinate, latitudinalMeters: 60_000, longitudinalMeters: 60_000)))
    }

    var body: some View {
        VStack(spacing: 0) {
            self.searchField
                .padding()
            ZStack(alignment: .top) {
                self.map
                if self.searching == true, self.query.isEmpty == false, self.search.suggestions.isEmpty == false {
                    self.suggestions
                }
            }
            self.footer
        }
        #if os(macOS)
        .frame(minWidth: 560, minHeight: 520)
        #endif
        .onChange(of: self.query) { _, query in
            self.search.update(query: query)
        }
    }

    private var status: some View {
        Text(self.statusText)
            .foregroundStyle(self.selection.status == .outside ? Color.red : Color.secondary)
            .lineLimit(1)
            .truncationMode(.tail)
    }

    /// The status and Start: side by side in a window, stacked on a phone, where the bottom action spans the width.
    @ViewBuilder private var footer: some View {
        #if os(iOS)
        VStack(spacing: 10) {
            self.status
                .frame(maxWidth: .infinity, alignment: .leading)
            self.startButton
                .controlSize(.large)
        }
        .padding()
        #else
        HStack {
            self.status
            Spacer()
            self.startButton
        }
        .padding()
        #endif
    }

    private var startButton: some View {
        Button {
            guard let location = self.selection.location else { return }
            self.onStart(location, self.selection.placeName)
        } label: {
            Text("Start")
                #if os(iOS)
                .frame(maxWidth: .infinity)
                #endif
        }
        .keyboardShortcut(.defaultAction)
        .buttonStyle(.borderedProminent)
        .disabled(self.selection.canStart == false)
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search for a place in Germany", text: self.$query)
                .textFieldStyle(.plain)
                .focused(self.$searching)
                .onSubmit {
                    if let first = self.search.suggestions.first { self.choose(first) }
                }
            if self.query.isEmpty == false {
                Button {
                    self.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Clear")
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Self.fieldBackground))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Self.fieldBorder))
    }

    #if os(macOS)
    private static let fieldBackground = Color(nsColor: .controlBackgroundColor)
    private static let fieldBorder = Color(nsColor: .separatorColor)
    #else
    private static let fieldBackground = Color(uiColor: .secondarySystemBackground)
    private static let fieldBorder = Color(uiColor: .separator)
    #endif

    /// Clicks become coordinates by the map's visible rectangle, the arithmetic the labels use, rather than `MapReader`, which placed
    /// points off inside the dashboard popup.
    private var map: some View {
        Map(
            position: self.$camera,
            bounds: MapCameraBounds(centerCoordinateBounds: Self.germany, minimumDistance: 1_500, maximumDistance: 1_800_000),
            interactionModes: [.pan, .zoom]
        ) {
            if let location = self.selection.location {
                Marker("Simulated location", systemImage: "mappin", coordinate: location.coordinate)
                    .tint(.orange)
            }
        }
        .onMapCameraChange(frequency: .continuous) { context in
            self.visibleRect = context.rect
        }
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { size in
            self.mapSize = size
        }
        .onTapGesture(coordinateSpace: .local) { point in
            self.searching = false
            guard let coordinate = MapProjection.coordinate(for: point, in: self.visibleRect, size: self.mapSize) else { return }
            self.pick(Location(latitude: coordinate.latitude, longitude: coordinate.longitude), move: false)
        }
    }

    private var suggestions: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(self.search.suggestions, id: \.self) { completion in
                    Button {
                        self.choose(completion)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(completion.title)
                            if completion.subtitle.isEmpty == false {
                                Text(completion.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Divider()
                }
            }
        }
        .frame(maxHeight: 240)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
    }

    private var statusText: String {
        switch self.selection.status {
            case .none:
                return "Click the map or search for a place."
            case .checking:
                return "Checking the place…"
            case .inGermany(let address):
                return address
            case .outside:
                return "Pick a place in Germany."
        }
    }

    /// A search result: the pin goes there and the camera follows.
    private func choose(_ completion: MKLocalSearchCompletion) {
        self.searching = false
        Task {
            guard let coordinate = await self.search.coordinate(for: completion) else { return }
            self.pick(Location(latitude: coordinate.latitude, longitude: coordinate.longitude), move: true)
        }
    }

    private func pick(_ location: Location, move: Bool) {
        if move == true {
            self.camera = .region(MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 20_000, longitudinalMeters: 20_000))
        }
        Task {
            await self.selection.select(location)
        }
    }
}

/// Suggestions for what is typed, from MapKit's completer, limited to Germany.
@MainActor @Observable final class SimulationSearch: NSObject, MKLocalSearchCompleterDelegate {
    private(set) var suggestions: [MKLocalSearchCompletion] = []
    @ObservationIgnored private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        self.completer.delegate = self
        self.completer.resultTypes = [.address, .pointOfInterest]
        self.completer.region = SimulationView.germany
        // Only places in the region, not merely those near it first; a pick abroad would be refused anyway.
        self.completer.regionPriority = .required
    }

    func update(query: String) {
        if query.isEmpty == true {
            self.completer.cancel()
            self.suggestions = []
        }
        else {
            self.completer.queryFragment = query
        }
    }

    /// Where a suggestion is, by a search for it.
    func coordinate(for completion: MKLocalSearchCompletion) async -> CLLocationCoordinate2D? {
        let request = MKLocalSearch.Request(completion: completion)
        request.region = SimulationView.germany
        request.regionPriority = .required
        guard let item = try? await MKLocalSearch(request: request).start().mapItems.first else { return nil }
        if #available(macOS 26, *) {
            return item.location.coordinate
        }
        return item.placemark.coordinate
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        MainActor.assumeIsolated {
            self.suggestions = completer.results
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: any Error) {
        MainActor.assumeIsolated {
            self.suggestions = []
        }
    }
}
