import DoomKitLocation
import DoomKitProcess
import MapKit
import SwiftUI

struct MapAnnotation: MapContent {
    let selector: ProcessSelector
    var user: Bool = false
    var simple: Bool = false
    let anchor: UnitPoint

    private let faceplate: String
    private let location: Location
    private let icon: String

    init(presenter: ProcessPresenter, selector: ProcessSelector, user: Bool = false, simple: Bool = false, anchor: UnitPoint = .bottomLeading) {
        self.selector = selector
        self.user = user
        self.simple = simple
        self.anchor = anchor

        self.faceplate = presenter.faceplate[self.selector] ?? "n/a"
        self.location = presenter.location
        self.icon = presenter.icon
    }

    var body: some MapContent {
        if self.simple == false {
            Annotation("", coordinate: self.location.coordinate, anchor: self.anchor) {
                #if os(iOS)
                VStack {
                    Spacer()
                    Image(systemName: self.icon)
                    Spacer()
                    VStack(alignment: .leading) {
                        Text(self.faceplate)
                            .font(.footnote)
                    }
                    Spacer()
                }
                .frame(width: 81, height: 57)
                .padding(5)
                .padding(.horizontal, 5)
                .background(
                    RoundedRectangle(cornerRadius: 13)
                        .fill(Color.faceplate(selector: self.selector))
                        .opacity(0.5)
                )
                .font(.title)
                .foregroundStyle(.black)
                #else
                MapAnnotationLabel(selector: self.selector, icon: self.icon, faceplate: self.faceplate)
                #endif
            }
        }
        Annotation("", coordinate: self.location.coordinate, anchor: .center) {
            VStack {
                if user == true {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 15, height: 15)
                        Circle()
                            .fill(Color.faceplate(selector: self.selector))
                            .frame(width: 11, height: 11)
                    }
                }
                else {
                    Circle()
                        .fill(Color.faceplate(selector: self.selector))
                        .frame(width: 11, height: 11)

                }
            }
        }
    }
}
