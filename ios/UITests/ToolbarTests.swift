import XCTest

@MainActor
final class ToolbarTests: XCTestCase {
    func testSeparateSensorScreensShowSixSensorsOrOnlyTheNearest() {
        self.continueAfterFailure = false
        let app = self.launch(sourcesEnabled: true, extra: ["-multiSensorLevel", "YES", "-multiSensorRadiation", "YES"])
        let names = [
            ["HKW, Berlin", "Berlin-Mühlendamm OP", "Berlin-Charlottenburg UP", "Berlin-Spandau OP", "Berlin-Köpenick", "Berlin-Schmöckwitz"],
            ["HKW, Berlin", "Berlin-Marzahn", "Berlin-Tegel", "Berlin-Buch", "Berlin-Wannsee", "Berlin-Köpenick"]
        ]
        for slot in 0 ..< 2 {
            app.buttons["toolbar.slot.\(slot)"].tap()
            for name in names[slot] {
                XCTAssertTrue(app.staticTexts[name].exists, "Missing sensor: \(name)")
            }
            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            attachment.name = slot == 0 ? "six-level-sensors" : "six-radiation-sensors"
            attachment.lifetime = .keepAlways
            self.add(attachment)
        }
        app.terminate()
        app.launchArguments = ["--ui-fixture", "--reset-toolbar", "-multiSensorLevel", "NO", "-multiSensorRadiation", "NO"]
        app.launch()
        XCTAssertTrue(app.buttons["toolbar.home"].waitForExistence(timeout: 15))
        for slot in 0 ..< 2 {
            app.buttons["toolbar.slot.\(slot)"].tap()
            XCTAssertTrue(app.staticTexts["HKW, Berlin"].exists)
            for name in names[slot].dropFirst() {
                XCTAssertFalse(app.staticTexts[name].exists, "Extra sensor shown with Multiple Sensors off: \(name)")
            }
        }
    }

    func testCustomizationSwapsAndPersistsAcrossLaunches() {
        self.continueAfterFailure = false
        let app = self.launch(sourcesEnabled: true)
        self.assertToolbar(app, labels: ["Level", "Radiation", "Particles", "COVID-19"])
        self.choose("energy", at: 0, in: app)
        self.assertToolbar(app, labels: ["Energy", "Radiation", "Particles", "COVID-19"])
        XCTAssertTrue(app.buttons["toolbar.slot.0"].isSelected)
        self.choose("particles", at: 0, in: app)
        self.assertToolbar(app, labels: ["Particles", "Radiation", "Energy", "COVID-19"])
        XCTAssertTrue(app.buttons["toolbar.slot.0"].isSelected)
        self.choose("surveys", at: 3, in: app)
        self.assertToolbar(app, labels: ["Particles", "Radiation", "Energy", "Election Polls"])
        XCTAssertTrue(app.buttons["toolbar.slot.3"].isSelected)
        app.terminate()
        app.launchArguments.removeAll { $0 == "--reset-toolbar" }
        app.launch()
        XCTAssertTrue(app.buttons["toolbar.home"].waitForExistence(timeout: 15))
        self.assertToolbar(app, labels: ["Particles", "Radiation", "Energy", "Election Polls"])
        XCTAssertTrue(app.buttons["toolbar.home"].isSelected)
        // The fixed buttons have no customization menu.
        for identifier in ["toolbar.home", "toolbar.weather", "toolbar.settings"] {
            app.buttons[identifier].press(forDuration: 1)
            XCTAssertFalse(app.buttons["toolbar.choice.energy"].exists)
        }
    }

    func testAllSourcesOffKeepSevenCustomizableButtons() {
        self.continueAfterFailure = false
        let app = self.launch(sourcesEnabled: false)
        self.assertToolbar(app, labels: ["Level", "Radiation", "Particles", "COVID-19"])
        for slot in 0 ..< 4 {
            let button = app.buttons["toolbar.slot.\(slot)"]
            XCTAssertEqual(button.value as? String, "Source off")
            button.tap()
            XCTAssertTrue(app.buttons["toolbar.home"].isSelected)
        }
        self.choose("energy", at: 0, in: app)
        self.assertToolbar(app, labels: ["Energy", "Radiation", "Particles", "COVID-19"])
        XCTAssertEqual(app.buttons["toolbar.slot.0"].value as? String, "Source off")
        XCTAssertTrue(app.buttons["toolbar.home"].isSelected)
        self.choose("radiation", at: 0, in: app)
        self.assertToolbar(app, labels: ["Radiation", "Energy", "Particles", "COVID-19"])
        app.buttons["toolbar.weather"].tap()
        self.choose("surveys", at: 3, in: app)
        XCTAssertTrue(app.buttons["toolbar.weather"].isSelected)
    }

    func testDisabledReplacementOfTheOpenScreenReturnsHome() {
        self.continueAfterFailure = false
        let app = self.launch(sourcesEnabled: false, extra: ["-showWater", "YES"])
        app.buttons["toolbar.slot.0"].tap()
        XCTAssertTrue(app.buttons["toolbar.slot.0"].isSelected)
        self.choose("energy", at: 0, in: app)
        XCTAssertTrue(app.buttons["toolbar.home"].isSelected)
        self.assertToolbar(app, labels: ["Energy", "Radiation", "Particles", "COVID-19"])
    }

    private func launch(sourcesEnabled: Bool, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-fixture", "--reset-toolbar", "-enableDarkTheme", "NO"]
        for key in ["showWater", "showRadiation", "showParticles", "enableCovid", "enableEnergy", "enableElectionPolls"]
        where extra.contains("-\(key)") == false {
            app.launchArguments += ["-\(key)", sourcesEnabled == true ? "YES" : "NO"]
        }
        app.launchArguments += extra
        app.launch()
        XCTAssertTrue(app.buttons["toolbar.settings"].waitForExistence(timeout: 15))
        return app
    }

    private func choose(_ screen: String, at slot: Int, in app: XCUIApplication) -> Void {
        app.buttons["toolbar.slot.\(slot)"].press(forDuration: 1)
        let choice = app.buttons["toolbar.choice.\(screen)"]
        XCTAssertTrue(choice.waitForExistence(timeout: 5))
        if screen == "energy" && slot == 0 {
            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            attachment.name = "toolbar-screen-choices"
            attachment.lifetime = .keepAlways
            self.add(attachment)
        }
        choice.tap()
        XCTAssertTrue(choice.waitForNonExistence(timeout: 5))
    }

    private func assertToolbar(_ app: XCUIApplication, labels: [String]) -> Void {
        let buttons = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "toolbar."))
        XCTAssertEqual(buttons.count, 7)
        XCTAssertEqual(app.buttons["toolbar.home"].label, "Home")
        XCTAssertEqual(app.buttons["toolbar.weather"].label, "Weather")
        XCTAssertEqual(app.buttons["toolbar.settings"].label, "Settings")
        for (slot, label) in labels.enumerated() {
            XCTAssertEqual(app.buttons["toolbar.slot.\(slot)"].label, label)
        }
    }
}
