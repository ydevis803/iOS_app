import XCTest

/// End-to-end walkthrough of FreshTrack on an iPhone simulator.
///
/// Drives every reachable screen (Home → Kitchen/Pantry → Calendar → Recipes →
/// Shopping list → Scanner → delete flow) and captures a screenshot at each step.
/// Screenshots are attached to the test result and, when the `SCREENSHOT_DIR`
/// environment variable is set (pass `TEST_RUNNER_SCREENSHOT_DIR` to xcodebuild),
/// also written as PNG files so CI can publish them.
final class FreshTrackUITests: XCTestCase {
    private var app: XCUIApplication!

    private var screenshotDirectory: URL? {
        ProcessInfo.processInfo.environment["SCREENSHOT_DIR"].map { URL(fileURLWithPath: $0) }
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        // The root view requests notification permission on launch.
        allowSystemPermissionIfPrompted()
    }

    // MARK: - Walkthrough

    func testWalkthroughOnIPhone() throws {
        // 1. Home dashboard -------------------------------------------------
        XCTAssertTrue(app.staticTexts["Freshness Score"].waitForExistence(timeout: 15), "Home screen did not appear")
        XCTAssertTrue(app.staticTexts["30%"].exists, "Sample pantry should score 3 fresh of 10 = 30%")
        XCTAssertTrue(app.staticTexts["3 Fresh"].exists)
        XCTAssertTrue(app.staticTexts["5 Warning"].exists)
        XCTAssertTrue(app.staticTexts["2 Critical"].exists)
        XCTAssertTrue(app.staticTexts["Expiring Soon"].exists)
        XCTAssertTrue(app.staticTexts["Baby Spinach"].exists)
        XCTAssertTrue(app.staticTexts["TODAY"].exists, "Spinach expires today and should show the TODAY chip")
        capture("01-home")

        // 2. Kitchen → Pantry list ---------------------------------------
        button(containing: "KITCHEN").tap()
        XCTAssertTrue(app.staticTexts["My Pantry"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Baby Spinach"].exists)
        XCTAssertTrue(app.staticTexts["Bottom Drawer"].firstMatch.exists)
        XCTAssertTrue(app.staticTexts["Sourdough Bread"].exists)
        XCTAssertTrue(app.staticTexts["TOMORROW"].exists)
        capture("02-pantry-list")

        // 3. Calendar view ------------------------------------------------
        button(containing: "Calendar View").tap()
        let monthTitle = monthYearTitle(for: Date())
        XCTAssertTrue(app.staticTexts[monthTitle].waitForExistence(timeout: 5), "Expected month header \(monthTitle)")
        XCTAssertTrue(app.staticTexts["2-4 DAYS"].exists, "Legend should be visible")
        capture("03-pantry-calendar")

        // Tap today's cell and expect the drill-down list.
        let todayNumber = String(Calendar.current.component(.day, from: Date()))
        let todayCell = app.staticTexts[todayNumber].firstMatch
        XCTAssertTrue(todayCell.waitForExistence(timeout: 5))
        scrollUntilHittable(todayCell)
        todayCell.tap()
        let expiringHeader = "Expiring on \(Date().formatted(.dateTime.month(.wide).day()))"
        XCTAssertTrue(app.staticTexts[expiringHeader].waitForExistence(timeout: 5), "Expected header \(expiringHeader)")
        XCTAssertTrue(app.staticTexts["Baby Spinach"].exists, "Spinach expires today and should be listed under the selected date")
        capture("04-calendar-selected-day")

        // 4. Recipes (batch cooking) -------------------------------------
        button(containing: "Recipes").tap()
        XCTAssertTrue(app.staticTexts["Smart Kitchen Prep"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Classic Pot Roast"].exists, "Pot roast uses 3 expiring ingredients and should rank first")
        XCTAssertTrue(app.staticTexts["URGENT PREP"].firstMatch.exists)
        XCTAssertTrue(app.staticTexts["6 Portions"].exists)
        XCTAssertTrue(app.staticTexts["Beef Chuck (2 days)"].exists, "Ingredient chip should show days-to-expiry from the pantry")
        capture("05-recipes")

        // 5. Shopping list: add an item ----------------------------------
        let shoppingHeader = app.staticTexts["Shopping List"]
        scrollUntilHittable(shoppingHeader)
        XCTAssertTrue(app.staticTexts["Whole Milk"].exists)
        XCTAssertTrue(app.staticTexts["Expired yesterday"].exists)

        let addItem = button(containing: "Add Item")
        scrollUntilHittable(addItem)
        addItem.tap()

        let field = app.textFields["Item name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Inline add field should appear")
        field.tap()
        field.typeText("Bananas\n")
        XCTAssertTrue(app.staticTexts["Bananas"].waitForExistence(timeout: 5), "New shopping item should be listed")
        capture("06-shopping-list-added")

        // 6. Scanner (no camera on the simulator, UI only) ----------------
        button(containing: "SCAN").tap()
        XCTAssertTrue(app.staticTexts["Auto-Scanning"].waitForExistence(timeout: 5), "Scanner overlay should be presented")
        // First use asks for camera access unless CI pre-granted it.
        allowSystemPermissionIfPrompted(timeout: 3)
        #if targetEnvironment(simulator)
        // The simulator has no camera: granted access ends in "No camera available",
        // a refusal in "Camera access is off". Either way the user must be told.
        let cameraNotice = app.staticTexts.matching(
            NSPredicate(format: "label IN %@", ["No camera available", "Camera access is off"])
        ).firstMatch
        XCTAssertTrue(cameraNotice.waitForExistence(timeout: 5),
                      "The scanner should explain why there is no live camera feed")
        #endif
        capture("07-scanner")
        let close = app.buttons["scanner.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        close.tap()
        XCTAssertTrue(waitForDisappearance(app.staticTexts["Auto-Scanning"], timeout: 5), "Scanner should dismiss")

        // 7. Delete a pantry item via its context menu --------------------
        button(containing: "Pantry").tap()
        let spinach = app.staticTexts["Baby Spinach"].firstMatch
        XCTAssertTrue(spinach.waitForExistence(timeout: 5))
        spinach.press(forDuration: 1.2)
        let delete = app.buttons["Delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5), "Context menu should offer Delete")
        capture("08-pantry-context-menu")
        delete.tap()
        XCTAssertTrue(waitForDisappearance(spinach, timeout: 5), "Deleted item should leave the list")
        capture("09-pantry-after-delete")

        // 8. Home reflects the deletion ----------------------------------
        button(containing: "HOME").tap()
        XCTAssertTrue(app.staticTexts["Freshness Score"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["33%"].waitForExistence(timeout: 5), "3 fresh of 9 remaining = 33%")
        XCTAssertTrue(app.staticTexts["1 Critical"].exists)
        capture("10-home-after-delete")

        // 9. Manual entry from the Home quick action ----------------------
        // Quick Actions sit below the expiring list, under the floating nav bar,
        // so bring the card fully into view before tapping.
        let addManual = button(containing: "Add Manual")
        scrollUntilHittable(addManual)
        addManual.tap()
        let sheetTitle = app.staticTexts["ITEM NAME"]
        XCTAssertTrue(sheetTitle.waitForExistence(timeout: 5), "Add Manual should open the entry sheet")

        let nameField = app.textFields["e.g. Baby Spinach"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("Oat Milk\n")

        let save = button(containing: "Add & Set 2-Day Alert")
        scrollUntilHittable(save) // scrolling also dismisses the keyboard
        capture("11-add-item-sheet")
        save.tap()
        // Saving schedules a calendar event, which prompts for calendar access.
        allowSystemPermissionIfPrompted()
        XCTAssertTrue(waitForDisappearance(sheetTitle, timeout: 15), "Sheet should dismiss after saving")

        // Default expiry is 7 days out, so the new item counts as fresh: 4 of 10 = 40%.
        XCTAssertTrue(app.staticTexts["40%"].waitForExistence(timeout: 5), "Manual item should raise the score to 40%")
        XCTAssertTrue(app.staticTexts["4 Fresh"].exists)
        capture("12-home-after-manual-add")

        // The item is in the pantry list, sorted by expiry near the bottom.
        button(containing: "KITCHEN").tap()
        XCTAssertTrue(app.staticTexts["My Pantry"].waitForExistence(timeout: 5))
        let oatMilk = app.staticTexts["Oat Milk"]
        scrollUntilHittable(oatMilk)
        capture("13-pantry-with-manual-item")

        // The pantry now offers manual entry too.
        let addManually = button(containing: "Add Manually")
        scrollUntilHittable(addManually)
        addManually.tap()
        XCTAssertTrue(sheetTitle.waitForExistence(timeout: 5), "Pantry's Add Manually should open the same sheet")
        capture("14-pantry-add-manually-sheet")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(waitForDisappearance(sheetTitle, timeout: 5))

        // And the pantry's primary button opens the scanner.
        let logNew = button(containing: "Log New Ingredients")
        scrollUntilHittable(logNew)
        logNew.tap()
        XCTAssertTrue(app.staticTexts["Auto-Scanning"].waitForExistence(timeout: 5), "Log New Ingredients should open the scanner")
        app.buttons["scanner.close"].tap()
        XCTAssertTrue(waitForDisappearance(app.staticTexts["Auto-Scanning"], timeout: 5))
    }

    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    // MARK: - Helpers

    /// Finds a button whose accessibility label contains `text` (SwiftUI buttons that
    /// combine an image and a label can carry the symbol description in their label).
    private func button(containing text: String) -> XCUIElement {
        let predicate = NSPredicate(format: "label CONTAINS[c] %@", text)
        let match = app.buttons.matching(predicate).firstMatch
        XCTAssertTrue(match.waitForExistence(timeout: 5), "No button containing '\(text)'")
        return match
    }

    private func scrollUntilHittable(_ element: XCUIElement, maxSwipes: Int = 8) {
        var swipes = 0
        while !(element.exists && element.isHittable) && swipes < maxSwipes {
            dragScrollUp()
            swipes += 1
        }
        XCTAssertTrue(element.exists && element.isHittable, "Could not scroll \(element) into view")
    }

    /// Swipes up, then lets the scroll view finish decelerating: a tap that lands
    /// during deceleration is swallowed by the scroll view.
    private func dragScrollUp() {
        app.swipeUp()
        usleep(600_000)
    }

    private func waitForDisappearance(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    /// Taps "Allow…" on a system permission alert if one is showing.
    private func allowSystemPermissionIfPrompted(timeout: TimeInterval = 6) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Allow'")).firstMatch
        if allow.waitForExistence(timeout: timeout) {
            allow.tap()
        }
    }

    private func monthYearTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    private func capture(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        guard let directory = screenshotDirectory else { return }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try screenshot.pngRepresentation.write(to: directory.appendingPathComponent("\(name).png"))
        } catch {
            XCTFail("Could not write screenshot \(name): \(error)")
        }
    }
}
