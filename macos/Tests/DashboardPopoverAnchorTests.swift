import CoreGraphics
import Testing

@Suite struct DashboardPopoverAnchorTests {
    private let main = CGRect(x: 0, y: 0, width: 1512, height: 982)
    private let second = CGRect(x: 1512, y: 0, width: 2560, height: 1440)

    @Test func aButtonOnScreenIsTheAnchor() {
        let button = CGRect(x: 1200, y: 945, width: 60, height: 37)
        #expect(DashboardPopoverAnchor.rect(button: button, screens: [self.main], menuBarScreen: self.main, menuBarHeight: 37) == button)
    }

    @Test func aButtonOnTheSecondScreenStaysThere() {
        let button = CGRect(x: 3800, y: 1416, width: 60, height: 24)
        let anchor = DashboardPopoverAnchor.rect(button: button, screens: [self.main, self.second], menuBarScreen: self.main, menuBarHeight: 37)
        #expect(anchor == button)
    }

    @Test func aButtonAMenuBarManagerPushedOffScreenFallsBackToTheRightEndOfTheMenuBar() {
        let button = CGRect(x: -8000, y: 945, width: 60, height: 37)
        let anchor = DashboardPopoverAnchor.rect(button: button, screens: [self.main], menuBarScreen: self.main, menuBarHeight: 37)
        #expect(anchor == CGRect(x: 1482, y: 945, width: 22, height: 37))
    }

    @Test func aMissingButtonFallsBackToTheRightEndOfTheMenuBar() {
        let anchor = DashboardPopoverAnchor.rect(button: nil, screens: [self.main], menuBarScreen: self.main, menuBarHeight: 24)
        #expect(anchor == CGRect(x: 1482, y: 958, width: 22, height: 24))
    }
}
