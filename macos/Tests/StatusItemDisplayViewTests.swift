import AppKit
import Testing

@MainActor
@Suite struct StatusItemDisplayViewTests {
    @Test func theTagIsAlwaysTheApps() {
        #expect(StatusItemDisplayView.tag == "DOD")
    }

    @Test func theWidthFollowsTheWidestValue() {
        let short = StatusItemDisplayView.requiredWidth(for: ["8°C"])
        let long = StatusItemDisplayView.requiredWidth(for: ["18.2°C"])
        #expect(short > 0)
        #expect(long > short)
        #expect(StatusItemDisplayView.requiredWidth(for: []) == 0)
    }

    @Test func twoStackedValuesUseTheSmallerFont() {
        let single = StatusItemDisplayView.requiredWidth(for: ["12.3µg/m³"])
        let stacked = StatusItemDisplayView.requiredWidth(for: ["12.3µg/m³", "12.3µg/m³"])
        #expect(stacked < single)
    }

    @Test func itDrawsWithoutFailing() {
        let view = StatusItemDisplayView(frame: NSRect(x: 0, y: 0, width: 80, height: 22))
        view.configure(values: ["18.2°C", "0.09µSv"])
        let image = NSImage(size: view.bounds.size)
        image.lockFocus()
        view.draw(view.bounds)
        image.unlockFocus()
        #expect(image.size.width == 80)
    }
}
