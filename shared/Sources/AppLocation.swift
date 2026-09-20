import DoomKitLocation

@MainActor
enum AppLocation {
    static let fallback = Location(latitude: 52.51889, longitude: 13.36528)
    #if os(iOS)
    static let shared = LocationManager(fallback: Self.fallback, configuration: .continuousBackground)
    #else
    static let shared = LocationManager(fallback: Self.fallback)
    #endif
}
