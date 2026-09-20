import DoomKitLocation
import DoomKitProcess
import SwiftUI

struct MapAnnotationSnapshot: Identifiable {
    let id: String
    let location: Location
    let selector: ProcessSelector
    let icon: String
    let faceplate: String
    let user: Bool
    let showsLabel: Bool
    /// A color of its own for this sensor, or nil for the color of its selector, which is what every home map annotation has.
    let color: Color?

    /// The color of the dot, the label and the connector.
    var displayColor: Color {
        return self.color ?? Color.faceplate(selector: self.selector)
    }

    @MainActor init(id: String, presenter: ProcessPresenter, selector: ProcessSelector, user: Bool = false, showsLabel: Bool = true, location: Location? = nil) {
        self.id = id
        self.location = location ?? presenter.location
        self.selector = selector
        self.icon = presenter.icon
        self.faceplate = presenter.faceplate[selector] ?? "n/a"
        self.user = user
        self.showsLabel = showsLabel
        self.color = nil
    }

    /// A snapshot from explicit values, for a sensor that is not the nearest one of its presenter, such as a further reading.
    init(id: String, location: Location, selector: ProcessSelector, icon: String, faceplate: String, showsLabel: Bool = true, color: Color? = nil) {
        self.id = id
        self.location = location
        self.selector = selector
        self.icon = icon
        self.faceplate = faceplate
        self.user = false
        self.showsLabel = showsLabel
        self.color = color
    }
}
