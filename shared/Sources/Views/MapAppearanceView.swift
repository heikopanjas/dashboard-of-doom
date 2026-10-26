#if os(macOS)
import MapKit
import SwiftUI

/// Gives the `MKMapView` behind a SwiftUI `Map` the appearance of the color scheme, which it does not take on by itself on macOS: with
/// the app set to the dark theme, a map without this stays light. Placed as the map's background, it looks for the nearest map view up
/// the hierarchy, which is that map's own.
struct MapAppearanceView: NSViewRepresentable {
    let colorScheme: ColorScheme

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        self.applyAppearance(from: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) -> Void {
        self.applyAppearance(from: nsView)
    }

    /// Deferred, because the map view is not in the hierarchy yet while SwiftUI builds this one.
    private func applyAppearance(from view: NSView) -> Void {
        let appearance = NSAppearance(named: self.colorScheme == .dark ? .darkAqua : .aqua)
        DispatchQueue.main.async {
            var ancestor = view.superview
            while let currentView = ancestor {
                if let mapView = Self.findMapView(in: currentView) {
                    mapView.appearance = appearance
                    mapView.needsDisplay = true
                    return
                }
                ancestor = currentView.superview
            }
        }
    }

    private static func findMapView(in view: NSView) -> MKMapView? {
        if let mapView = view as? MKMapView {
            return mapView
        }
        for subview in view.subviews {
            if let mapView = Self.findMapView(in: subview) {
                return mapView
            }
        }
        return nil
    }
}
#endif
