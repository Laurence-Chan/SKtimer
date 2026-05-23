import XCTest

final class SKtimerUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-state"]
    }

    override func tearDownWithError() throws {
        app = nil
    }

    @MainActor
    func testCreatesPausesResumesRestartsAndDeletesTimer() throws {
        app.launch()

        let minutesField = app.textFields["minutesField"]
        XCTAssertTrue(minutesField.waitForExistence(timeout: 5))
        minutesField.click()
        minutesField.typeKey("a", modifierFlags: [.command])
        minutesField.typeText("1")

        app.buttons["startTimerButton"].click()
        XCTAssertTrue(app.scrollViews["timerList"].waitForExistence(timeout: 3))

        let pauseButton = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "pauseResumeButton_")).firstMatch
        XCTAssertTrue(pauseButton.waitForExistence(timeout: 3))
        pauseButton.click()

        let resumeButton = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "pauseResumeButton_")).firstMatch
        XCTAssertTrue(resumeButton.waitForExistence(timeout: 3))
        resumeButton.click()

        let restartButton = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "restartButton_")).firstMatch
        XCTAssertTrue(restartButton.waitForExistence(timeout: 3))
        restartButton.click()

        let deleteButton = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "deleteButton_")).firstMatch
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 3))
        deleteButton.click()

        XCTAssertTrue(app.otherElements["emptyTimerState"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testInvalidInputShowsValidationError() throws {
        app.launch()

        let minutesField = app.textFields["minutesField"]
        XCTAssertTrue(minutesField.waitForExistence(timeout: 5))
        minutesField.click()
        minutesField.typeKey("a", modifierFlags: [.command])
        minutesField.typeText("0")

        app.buttons["startTimerButton"].click()
        XCTAssertTrue(app.staticTexts["inputErrorLabel"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testMeaningfulPromptYesUpdatesTodayStats() throws {
        app.launchArguments.append("--uitesting-fast-timers")
        app.launch()

        startOneMinuteTimer()

        let yesButton = app.buttons["meaningfulYesButton"]
        XCTAssertTrue(yesButton.waitForExistence(timeout: 8))
        yesButton.click()

        let todayValue = app.staticTexts["meaningfulStatsTodayValue"]
        XCTAssertTrue(todayValue.waitForExistence(timeout: 3))
        XCTAssertTrue(todayValue.waitForValue("1m", timeout: 3))
    }

    @MainActor
    func testMeaningfulPromptNoDoesNotUpdateTodayStats() throws {
        app.launchArguments.append("--uitesting-fast-timers")
        app.launch()

        startOneMinuteTimer()

        let noButton = app.buttons["meaningfulNoButton"]
        XCTAssertTrue(noButton.waitForExistence(timeout: 8))
        noButton.click()

        let todayValue = app.staticTexts["meaningfulStatsTodayValue"]
        XCTAssertTrue(todayValue.waitForExistence(timeout: 3))
        XCTAssertTrue(todayValue.waitForValue("0m", timeout: 3))
    }

    private func startOneMinuteTimer() {
        let minutesField = app.textFields["minutesField"]
        XCTAssertTrue(minutesField.waitForExistence(timeout: 5))
        minutesField.click()
        minutesField.typeKey("a", modifierFlags: [.command])
        minutesField.typeText("1")

        app.buttons["startTimerButton"].click()
    }
}

private extension XCUIElement {
    func waitForValue(_ expectedValue: String, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "label == %@", expectedValue)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}
