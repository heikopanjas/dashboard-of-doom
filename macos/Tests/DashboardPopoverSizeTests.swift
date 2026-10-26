import CoreGraphics
import Testing

@Suite struct DashboardPopoverSizeTests {
    @Test func aLargeScreenGetsThePreferredSize() {
        #expect(DashboardPopoverSize.size(visibleHeight: 1400) == CGSize(width: 800, height: 860))
    }

    @Test func aSmallScreenGetsWhatFitsBelowTheMenuBar() {
        // A 13-inch MacBook Air leaves about 918 points below the menu bar.
        #expect(DashboardPopoverSize.size(visibleHeight: 880).height == 840)
    }

    @Test func theHeightNeverDropsBelowWhatTheContentNeeds() {
        #expect(DashboardPopoverSize.size(visibleHeight: 600).height == 720)
    }
}
