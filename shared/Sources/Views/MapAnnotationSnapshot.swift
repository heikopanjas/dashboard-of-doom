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

    @MainActor init(id: String, presenter: ProcessPresenter, selector: ProcessSelector, user: Bool = false, showsLabel: Bool = true, location: Location? = nil) {
        self.id = id
        self.location = location ?? presenter.location
        self.selector = selector
        self.icon = presenter.icon
        self.faceplate = presenter.faceplate[selector] ?? "n/a"
        self.user = user
        self.showsLabel = showsLabel
    }
}
