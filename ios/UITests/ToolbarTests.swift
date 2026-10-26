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
        self.assertToolbar(app, labels: ["Water Level", "Radiation", "Particles", "COVID-19"])
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
        self.assertToolbar(app, labels: ["Water Level", "Radiation", "Particles", "COVID-19"])
        for slot in 0 ..< 4 {
            let button = app.buttons["toolbar.slot.\(slot)"]
            XCTAssertEqual(button.value as? String, "Source off")
            button.tap()
            XCTAssertTrue(app.buttons["toolbar.home"].isSelected)
        }
        // With every source off the menu offers nothing but a hint.
        app.buttons["toolbar.slot.0"].press(forDuration: 1)
        XCTAssertTrue(app.buttons["toolbar.choice.none"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["toolbar.choice.none"].isEnabled)
        for screen in ["energy", "particles", "covid", "level", "radiation", "surveys"] {
            XCTAssertFalse(app.buttons["toolbar.choice.\(screen)"].exists, "Disabled source offered: \(screen)")
        }
        self.dismissMenu(showing: "none", in: app)
        self.assertToolbar(app, labels: ["Water Level", "Radiation", "Particles", "COVID-19"])
        XCTAssertTrue(app.buttons["toolbar.home"].isSelected)
    }

    func testMenuListsOnlyEnabledSources() {
        self.continueAfterFailure = false
        let app = self.launch(sourcesEnabled: false, extra: ["-showWater", "YES", "-enableEnergy", "YES"])
        self.assertToolbar(app, labels: ["Water Level", "Radiation", "Particles", "COVID-19"])
        self.assertChoices(["level", "energy"], at: 0, in: app)
        self.choose("energy", at: 0, in: app)
        self.assertToolbar(app, labels: ["Energy", "Radiation", "Particles", "COVID-19"])
        XCTAssertTrue(app.buttons["toolbar.slot.0"].isSelected)
        // A slot holding a disabled source offers the same enabled sources, its own excluded.
        self.assertChoices(["level", "energy"], at: 1, in: app)
        self.choose("level", at: 1, in: app)
        self.assertToolbar(app, labels: ["Energy", "Water Level", "Particles", "COVID-19"])
        XCTAssertTrue(app.buttons["toolbar.slot.1"].isSelected)
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

    /// Open the menu of one slot and check it offers exactly these sources, then close it.
    private func assertChoices(_ screens: [String], at slot: Int, in app: XCUIApplication) -> Void {
        app.buttons["toolbar.slot.\(slot)"].press(forDuration: 1)
        XCTAssertTrue(app.buttons["toolbar.choice.\(screens[0])"].waitForExistence(timeout: 5))
        for screen in ["energy", "particles", "covid", "level", "radiation", "surveys"] {
            XCTAssertEqual(app.buttons["toolbar.choice.\(screen)"].exists, screens.contains(screen), "Choice: \(screen)")
        }
        XCTAssertFalse(app.buttons["toolbar.choice.none"].exists)
        self.dismissMenu(showing: screens[0], in: app)
    }

    private func dismissMenu(showing choice: String, in app: XCUIApplication) -> Void {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)).tap()
        XCTAssertTrue(app.buttons["toolbar.choice.\(choice)"].waitForNonExistence(timeout: 5))
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
