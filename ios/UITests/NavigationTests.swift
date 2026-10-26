import XCTest

@MainActor
final class NavigationTests: XCTestCase {
    func testEuropeanEnergyBenchmarks() {
        self.continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-fixture", "--reset-toolbar", "-enableEnergy", "YES"]
        app.launch()
        XCTAssertTrue(app.buttons["toolbar.slot.0"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts["Maritime · Middle East"].exists)
        app.buttons["toolbar.slot.0"].press(forDuration: 1)
        app.buttons["toolbar.choice.energy"].tap()
        for _ in 0 ..< 6 { app.swipeDown() }
        for title in ["Brent Spot", "Brent Futures", "TTF Futures", "LNG Spot"] {
            for _ in 0 ..< 8 {
                if app.staticTexts[title].isHittable { break }
                app.swipeUp()
            }
            XCTAssertTrue(app.staticTexts[title].exists)
        }
        self.capture("four-energy-benchmarks")
        XCTAssertFalse(app.staticTexts["MARAD advisories"].exists)
        XCTAssertFalse(app.staticTexts["CENTCOM reports"].exists)
    }

    func testNavigationGesturesAndDensePOIs() {
        self.continueAfterFailure = false
        let app = XCUIApplication()
        // The multi-sensor switches are off by default, so this launch turns them on to see every sensor. The second launch leaves them off.
        app.launchArguments = [
            "--ui-fixture", "--reset-toolbar", "-enableElectionPolls", "YES", "-showPlaces", "YES", "-enableDarkTheme", "NO",
            "-multiSensorLevel", "YES", "-multiSensorRadiation", "YES", "-multiSensorParticles", "YES", "-enableCovid", "YES"
        ]
        app.launch()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 15))
        self.capture("home-2000")
        for label in ["Weather", "Water Level", "Radiation", "Particles", "COVID-19", "Energy", "Election Polls", "Settings"] {
            if label == "Energy" || label == "Election Polls" {
                app.buttons["toolbar.slot.0"].press(forDuration: 1)
                let choice = label == "Energy" ? "energy" : "surveys"
                let menuItem = app.buttons["toolbar.choice.\(choice)"]
                XCTAssertTrue(menuItem.waitForExistence(timeout: 5))
                menuItem.tap()
            }
            else {
                app.buttons[label].tap()
            }
            XCTAssertTrue(app.buttons["Home"].exists)
            self.capture(label)
            if label == "Water Level" || label == "Radiation" || label == "Particles" || label == "Settings" || label == "Energy" {
                // Up to six sections per source, and a settings card per source, so these tabs are taller than the screen. Scroll back
                // afterwards: the offset would carry over.
                let steps = label == "Settings" ? ["middle", "lower", "bottom"] : ["middle", "bottom"]
                // Each sensor tab also has a map above its charts, which is about a screen taller.
                let swipes = label == "Water Level" || label == "Radiation" ? 3 : 2
                for step in steps {
                    for _ in 0 ..< swipes { app.swipeUp() }
                    self.capture("\(label)-\(step)")
                }
                for _ in 0 ..< 10 { app.swipeDown() }
            }
            if label != "Settings" {
                let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.4))
                let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.4))
                start.press(forDuration: 0.5, thenDragTo: end)
            }
        }
        app.buttons["Home"].tap()
        XCUIDevice.shared.orientation = .landscapeLeft
        self.capture("landscape-2000")
        XCUIDevice.shared.orientation = .portrait
        app.terminate()
        app.launchArguments = [
            "--ui-fixture", "--reset-toolbar", "--poi-10000", "-enableElectionPolls", "YES", "-showPlaces", "YES", "-enableDarkTheme", "YES",
            "-multiSensorLevel", "NO", "-multiSensorRadiation", "NO", "-multiSensorParticles", "NO",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        app.launch()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 15))
        self.capture("home-dark-large-text-10000")
        app.buttons["Water Level"].tap()
        self.capture("level-dark-large-text")
        app.buttons["Radiation"].tap()
        self.capture("radiation-dark-large-text")
        app.buttons["Home"].tap()
        XCUIDevice.shared.orientation = .landscapeLeft
        self.capture("landscape-dark-10000")
        XCUIDevice.shared.orientation = .portrait
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        self.add(attachment)
    }
}
