import XCTest

final class CalculatorUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func assertKeyBounds(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let viewport = app.windows.firstMatch.frame
        for button in app.buttons.allElementsBoundByIndex where button.identifier.hasPrefix("key_") || button.identifier.hasPrefix("science_") {
            let frame = button.frame
            XCTAssertGreaterThanOrEqual(frame.minX, viewport.minX + 15, button.identifier, file: file, line: line)
            XCTAssertLessThanOrEqual(frame.maxX, viewport.maxX - 15, button.identifier, file: file, line: line)
            XCTAssertGreaterThanOrEqual(frame.minY, viewport.minY, button.identifier, file: file, line: line)
            XCTAssertLessThanOrEqual(frame.maxY, viewport.maxY - 3, button.identifier, file: file, line: line)
        }
    }
    func testGridAndBasicInteraction() {
        let app = XCUIApplication(); app.launchArguments = ["-leftHandedLayout", "NO"]; app.launch()
        XCUIDevice.shared.orientation = .portrait
        let rows = [
            ["Backspace", "AC", "Percentage", "Divide"],
            ["Number7", "Number8", "Number9", "Multiply"],
            ["Number4", "Number5", "Number6", "Minus"],
            ["Number1", "Number2", "Number3", "Plus"],
            ["PlusMinus", "Number0", "Dot", "Calculate"]
        ]
        for row in rows {
            for key in row { XCTAssertTrue(app.buttons["key_" + key].isHittable, key) }
            let frames = row.map { app.buttons["key_" + $0].frame }
            for index in 1..<frames.count {
                XCTAssertEqual(frames[index].midY, frames[0].midY, accuracy: 1)
                XCTAssertGreaterThan(frames[index].midX, frames[index-1].midX)
                XCTAssertEqual(frames[index].width, frames[0].width, accuracy: 1)
                XCTAssertEqual(frames[index].width, frames[index].height, accuracy: 1)
            }
        }
        XCTAssertTrue(app.buttons["calculator_settings"].exists)
        assertKeyBounds(app)
        let first = app.buttons["key_Backspace"].frame
        let last = app.buttons["key_Divide"].frame
        if abs(app.frame.width - 466) < 1 {
            XCTAssertGreaterThan(first.width, 74)
            XCTAssertEqual(last.maxX, app.frame.maxX - 16, accuracy: 1)
        }
        app.buttons["key_Number7"].tap(); app.buttons["key_Plus"].tap(); app.buttons["key_Number5"].tap()
        XCTAssertEqual(app.staticTexts["calculator_display"].value as? String, "7+5")
        XCTAssertEqual(app.staticTexts["calculator_preview"].label, "= 12")
        XCTAssertFalse(app.staticTexts["calculator_expression"].exists)
        app.buttons["key_Calculate"].tap()
        XCTAssertEqual(app.staticTexts["calculator_display"].value as? String, "12")
        app.buttons["key_AC"].tap(); app.buttons["key_Number1"].tap(); app.buttons["key_Number2"].tap(); app.buttons["key_Backspace"].tap()
        XCTAssertEqual(app.staticTexts["calculator_display"].value as? String, "1")
        app.buttons["key_AC"].tap()
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = "Calculator Duo four-column layout"; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testLongExpressionScrollPreservesInput() {
        let app = XCUIApplication(); app.launchArguments = ["-leftHandedLayout", "NO"]; app.launch()
        XCUIDevice.shared.orientation = .portrait
        app.buttons["key_AC"].tap(); app.buttons["key_AC"].tap()
        for _ in 0..<5 {
            for digit in ["1", "2", "3", "4"] { app.buttons["key_Number" + digit].tap() }
            app.buttons["key_Plus"].tap()
        }
        app.buttons["key_Number5"].tap()
        let expected = "1234+1234+1234+1234+1234+5"
        let display = app.staticTexts["calculator_display"]
        XCTAssertEqual(display.value as? String, expected)
        display.swipeRight(); display.swipeLeft()
        XCTAssertEqual(display.value as? String, expected)
        XCTAssertFalse(app.textFields["expression_editor"].exists)
        app.buttons["key_Calculate"].tap()
        XCTAssertEqual(display.value as? String, "6,175")
        XCTAssertEqual(app.staticTexts["calculator_expression"].value as? String, expected)
    }
    func testRotationAndRepeatedClear() {
        let app = XCUIApplication(); app.launchArguments = ["-leftHandedLayout", "NO"]; app.launch()
        XCUIDevice.shared.orientation = .portrait
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.buttons["science_sin"].waitForExistence(timeout: 5))
        for key in ["Backspace", "Number7", "Number0", "Calculate"] { XCTAssertTrue(app.buttons["key_" + key].isHittable) }
        XCTAssertTrue(app.buttons["science_sin"].isHittable)
        let scientificShot = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); scientificShot.name = "Scientific calculator"; scientificShot.lifetime = .keepAlways; add(scientificShot)
        app.buttons["key_AC"].tap()
        app.buttons["key_Number3"].tap(); app.buttons["key_Number0"].tap()
        app.buttons["science_sin"].tap()
        XCTAssertEqual(app.staticTexts["calculator_preview"].label, "= 0.5")
        app.buttons["science_square"].tap()
        XCTAssertEqual(app.staticTexts["calculator_preview"].label, "= 0.25")
        app.buttons["angle_unit"].tap()
        XCTAssertEqual(app.buttons["angle_unit"].label, "Deg")
        app.buttons["angle_unit"].tap()
        app.buttons["key_AC"].tap(); app.buttons["key_AC"].tap()
        XCTAssertEqual(app.staticTexts["calculator_display"].value as? String, "0")
        XCTAssertTrue(app.buttons["calculator_settings"].isHittable)
        assertKeyBounds(app)
        app.buttons["calculator_settings"].tap()
        app.buttons["Left-handed"].tap()
        XCUIDevice.shared.orientation = .portrait
        let basicReady = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.buttons["science_sin"])
        XCTAssertEqual(XCTWaiter.wait(for: [basicReady], timeout: 5), .completed)
        let equalsReady = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: app.buttons["key_Calculate"])
        XCTAssertEqual(XCTWaiter.wait(for: [equalsReady], timeout: 5), .completed)
        XCTAssertTrue(app.buttons["calculator_settings"].exists)
        assertKeyBounds(app)
        XCTAssertEqual(app.buttons["key_Backspace"].frame.minX, 16, accuracy: 1)
    }
    func testScientificHistoryPreviewAndSecondFunctions() {
        let app = XCUIApplication(); app.launchArguments = ["-leftHandedLayout", "NO"]; app.launch()
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.buttons["science_second"].waitForExistence(timeout: 5))
        app.buttons["key_AC"].tap(); app.buttons["key_AC"].tap()
        app.buttons["key_Number2"].tap(); app.buttons["key_Plus"].tap()
        app.buttons["key_Number3"].tap(); app.buttons["key_Multiply"].tap(); app.buttons["key_Number4"].tap()
        XCTAssertEqual(app.staticTexts["calculator_display"].value as? String, "2+3×4")
        XCTAssertEqual(app.staticTexts["calculator_preview"].label, "= 14")
        app.buttons["key_Calculate"].tap()
        app.buttons["science_memory_add"].tap()
        app.buttons["key_AC"].tap(); app.buttons["key_AC"].tap()
        app.buttons["science_memory_recall"].tap()
        XCTAssertEqual(app.staticTexts["calculator_display"].value as? String, "14")
        app.buttons["science_memory_clear"].tap()
        app.buttons["key_AC"].tap(); app.buttons["key_AC"].tap()
        app.buttons["key_Number2"].tap(); app.buttons["science_exponent"].tap(); app.buttons["key_Number3"].tap()
        XCTAssertEqual(app.staticTexts["calculator_display"].value as? String, "2e3")
        app.buttons["key_AC"].tap(); app.buttons["key_AC"].tap()
        app.buttons["key_Number3"].tap(); app.buttons["science_second"].tap(); app.buttons["science_pow10"].tap()
        XCTAssertEqual(app.staticTexts["calculator_preview"].label, "= 8")
        app.buttons["science_second"].tap()
        app.buttons["calculator_history"].tap()
        XCTAssertTrue(app.buttons["history.close"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "equals 14")).firstMatch.exists)
        app.buttons["history.close"].tap()
        assertKeyBounds(app)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); shot.name = "Full scientific controls"; shot.lifetime = .keepAlways; add(shot)
    }

    func testPortraitScientificModeAndHistoryPersistence() {
        let app = XCUIApplication(); app.launch(); XCUIDevice.shared.orientation = .portrait
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.buttons["science_sin"])
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
        app.buttons["calculator_settings"].tap()
        app.buttons["Scientific"].tap()
        XCTAssertTrue(app.buttons["science_sin"].waitForExistence(timeout: 3))
        XCTAssertLessThan(app.buttons["science_random"].frame.maxY, app.buttons["key_Backspace"].frame.minY)
        assertKeyBounds(app)
        app.buttons["key_AC"].tap(); app.buttons["key_AC"].tap()
        app.buttons["key_Number6"].tap(); app.buttons["key_Multiply"].tap(); app.buttons["key_Number7"].tap(); app.buttons["key_Calculate"].tap()
        app.terminate(); app.launch(); XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.buttons["calculator_history"].waitForExistence(timeout: 5))
        app.buttons["calculator_history"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "equals 42")).firstMatch.exists)
        app.buttons["history.close"].tap()
    }

    func testInlineExpressionEditing() {
        let app = XCUIApplication(); app.launch(); XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.buttons["science_sin"].waitForExistence(timeout: 5))
        app.buttons["key_AC"].tap(); app.buttons["key_AC"].tap()
        app.buttons["key_Number2"].tap(); app.buttons["key_Plus"].tap(); app.buttons["key_Number3"].tap(); app.buttons["key_Calculate"].tap()
        app.staticTexts["calculator_display"].tap()
        let editor = app.textFields["expression_editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 3))
        XCTAssertEqual(editor.value as? String, "2+3")
        // Cursor begins at the end: delete just the final operand, not the whole expression.
        app.buttons["key_Backspace"].tap(); app.buttons["key_Number4"].tap()
        XCTAssertEqual(editor.value as? String, "2+4")
        XCTAssertTrue(app.staticTexts["editing_preview"].label.contains("6"))
        app.buttons["key_Calculate"].tap()
        XCTAssertEqual(app.staticTexts["calculator_display"].value as? String, "6")
        app.staticTexts["calculator_display"].tap()
        XCTAssertTrue(editor.waitForExistence(timeout: 3))
        // Tap before the expression to move the native caret, then insert at the start.
        editor.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.5)).tap()
        app.buttons["key_Number9"].tap()
        XCTAssertEqual(editor.value as? String, "92+4")
        XCTAssertTrue(app.staticTexts["editing_preview"].label.contains("96"))
        app.buttons["key_Calculate"].tap()
        XCTAssertEqual(app.staticTexts["calculator_display"].value as? String, "96")
    }

    func testNativeSelectionReplacement() {
        let app = XCUIApplication(); app.launch(); XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.buttons["science_sin"].waitForExistence(timeout: 5))
        app.buttons["key_AC"].tap(); app.buttons["key_AC"].tap()
        for digit in ["1", "2", "3", "4", "5"] { app.buttons["key_Number" + digit].tap() }
        app.staticTexts["calculator_display"].tap()
        let editor = app.textFields["expression_editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 3))
        editor.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)).doubleTap()
        app.buttons["key_Number9"].tap()
        XCTAssertEqual(editor.value as? String, "9")
        app.buttons["key_Calculate"].tap()
        XCTAssertEqual(app.staticTexts["calculator_display"].value as? String, "9")
    }

    func testFunctionalConvertMenu() {
        let app = XCUIApplication(); app.launch(); XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(app.buttons["calculator_settings"].waitForExistence(timeout: 5))
        app.buttons["key_AC"].tap(); app.buttons["key_AC"].tap(); app.buttons["key_Number1"].tap()
        app.buttons["calculator_settings"].tap(); app.buttons["Convert"].tap()
        XCTAssertTrue(app.buttons["conversion.category"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["conversion.output"].label.contains("3.280"))
        app.buttons["conversion.swap"].tap()
        XCTAssertEqual(Double(app.staticTexts["conversion.output"].label) ?? .nan, 1, accuracy: 1e-10)
        app.buttons["conversion.category"].tap()
        let categorySearch = app.textFields["conversion.search"]
        categorySearch.tap(); categorySearch.typeText("Temperature")
        let temperatureRow = app.buttons["conversion.option.Temperature"]
        XCTAssertTrue(temperatureRow.waitForExistence(timeout: 3))
        temperatureRow.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5)).tap()
        let pickedTemperature = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", "Temperature"), object: app.buttons["conversion.category"])
        XCTAssertEqual(XCTWaiter.wait(for: [pickedTemperature], timeout: 5), .completed)
        app.buttons["key_AC"].tap(); app.buttons["key_AC"].tap()
        XCTAssertEqual(app.staticTexts["conversion.output"].label, "32")
        assertKeyBounds(app)
        app.buttons["calculator_settings"].tap(); app.buttons["Convert"].tap()
        XCTAssertTrue(app.staticTexts["calculator_display"].exists)
    }

}
