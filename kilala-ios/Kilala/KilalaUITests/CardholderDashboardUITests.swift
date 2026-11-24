//
//  CardholderDashboardUITests.swift
//  KilalaUITests
//
//  Supporting tests (not in the MCO4 plan) for the cardholder dashboard added in
//  PR #53: the Home / Transactions / Profile tabs and the privacy cover over the QR
//  code. They need the backend on localhost:5001 and are skipped (not failed) when it
//  is not running. They only read data.
//

import XCTest

final class CardholderDashboardUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        // XCTest calls setUp on the main thread, so the main-actor-only XCUIDevice API is safe here.
        MainActor.assumeIsolated {
            XCUIDevice.shared.orientation = .portrait
        }
    }

    override func tearDownWithError() throws {
        // Close the app so the next test starts from a cold launch on the login screen.
        MainActor.assumeIsolated {
            let app = XCUIApplication()
            app.terminate()
            _ = app.wait(for: .notRunning, timeout: 5)
        }
    }

    /// The dashboard has Home, Transactions and Profile tabs and opens on Home.
    @MainActor
    func testDashboardShowsThreeTabsAndOpensOnHome() throws {
        try requireBackend()
        let app = logInAsCardholder()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5), "The dashboard tab bar is missing")
        for tab in [UIText.homeTab, UIText.transactionsTab, UIText.profileTab] {
            XCTAssertTrue(tabBar.buttons[tab].exists, "\(tab) tab missing")
        }
        XCTAssertTrue(tabBar.buttons[UIText.homeTab].isSelected, "The dashboard should open on Home")
        attachScreenshot(app, named: "Dashboard tabs")
    }

    /// The QR code is hidden when the dashboard opens; tapping it shows it, and tapping
    /// again hides it.
    @MainActor
    func testQRCodeIsHiddenUntilTapped() throws {
        try requireBackend()
        let app = logInAsCardholder()

        XCTAssertTrue(app.staticTexts[UIText.qrHiddenCaption].waitForExistence(timeout: 10),
                      "The QR code should be hidden when the dashboard opens")
        let qrCode = qrCodeCentre(app)
        attachScreenshot(app, named: "QR hidden")

        // The cover is faded out rather than removed, so it stays in the accessibility
        // tree; the caption below the code is what tells shown from hidden.
        toggleQRCode(app, at: qrCode, expecting: UIText.qrShownCaption) { $0.tap() }
        attachScreenshot(app, named: "QR shown")

        toggleQRCode(app, at: qrCode, expecting: UIText.qrHiddenCaption) { $0.tap() }
    }

    /// A swipe on the QR code also shows it, and leaving the Home tab hides it again.
    @MainActor
    func testSwipeShowsQRCodeAndLeavingHomeHidesIt() throws {
        try requireBackend()
        let app = logInAsCardholder()

        XCTAssertTrue(app.staticTexts[UIText.qrHiddenCaption].waitForExistence(timeout: 10))
        let qrCode = qrCodeCentre(app)
        toggleQRCode(app, at: qrCode, expecting: UIText.qrShownCaption) {
            $0.press(forDuration: 0.1, thenDragTo: $0.withOffset(CGVector(dx: 0, dy: -100)))
        }

        let tabBar = app.tabBars.firstMatch
        tabBar.buttons[UIText.transactionsTab].tap()
        XCTAssertTrue(tabBar.buttons[UIText.transactionsTab].isSelected, "Transactions tab did not open")
        tabBar.buttons[UIText.homeTab].tap()
        XCTAssertTrue(app.staticTexts[UIText.qrHiddenCaption].waitForExistence(timeout: 5),
                      "Coming back to Home should show the QR code hidden again")
    }

    // MARK: Helpers

    /// Logs in as Juan (PWD) and waits until his Digital ID has loaded.
    @MainActor
    private func logInAsCardholder(file: StaticString = #filePath, line: UInt = #line) -> XCUIApplication {
        let app = launchApp()
        logIn(app, email: UITestAccounts.cardholderPWD, password: UITestAccounts.password)
        dismissSavePasswordPromptIfShown(app)
        XCTAssertTrue(app.navigationBars[UIText.cardholderHome].waitForExistence(timeout: 15),
                      "Cardholder should land on the dashboard", file: file, line: line)
        XCTAssertTrue(app.staticTexts[UITestAccounts.juanFullName].waitForExistence(timeout: 10),
                      "Digital ID details did not load", file: file, line: line)
        return app
    }

    /// The centre of the QR code, taken from the privacy cover's hint (centred on the
    /// code). Read it while the code is hidden: the hint disappears once it is shown.
    @MainActor
    private func qrCodeCentre(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) -> XCUICoordinate {
        let hint = app.staticTexts[UIText.qrRevealHint]
        XCTAssertTrue(hint.waitForExistence(timeout: 5), "The QR privacy cover is missing", file: file, line: line)
        let frame = hint.frame
        return app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: frame.midX, dy: frame.midY))
    }

    /// Performs a gesture on the QR code and waits for the caption it should lead to.
    /// iOS's "Save Password?" prompt can appear a few seconds after login and swallow the
    /// gesture, so it is dismissed and the gesture repeated once.
    @MainActor
    private func toggleQRCode(_ app: XCUIApplication, at qrCode: XCUICoordinate, expecting caption: String,
                              file: StaticString = #filePath, line: UInt = #line,
                              gesture: (XCUICoordinate) -> Void) {
        dismissSavePasswordPromptIfShown(app, timeout: 1)
        gesture(qrCode)
        if app.staticTexts[caption].waitForExistence(timeout: 3) { return }
        dismissSavePasswordPromptIfShown(app, timeout: 1)
        gesture(qrCode)
        XCTAssertTrue(app.staticTexts[caption].waitForExistence(timeout: 3),
                      "Expected \"\(caption)\" after the gesture", file: file, line: line)
    }
}
