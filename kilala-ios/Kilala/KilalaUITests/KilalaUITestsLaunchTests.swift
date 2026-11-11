//
//  KilalaUITestsLaunchTests.swift
//  KilalaUITests
//
//  Created by Joshua Calibo on 10/21/26.
//
//  Sprint 1 – screenshot tests for review. Because
//  runsForEachTargetApplicationUIConfiguration is true, each test runs once per
//  UI configuration (for example light and dark appearance) and attaches a
//  screenshot for each. Open them in Xcode's Report navigator.
//

import XCTest

final class KilalaUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app
        // XCUIAutomation Documentation
        // https://developer.apple.com/documentation/xcuiautomation
        // Wait for the login screen so the screenshot is not taken mid-launch.
        XCTAssertTrue(app.staticTexts[UIText.appTitle].waitForExistence(timeout: 10),
                      "Login screen did not appear after launch")

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testLaunchCardholderSignup() throws {
        let app = launchApp()

        // Navigate to the cardholder signup screen.
        app.buttons[UIText.createAccount].tap()
        XCTAssertTrue(app.buttons[UIText.verifyRecord].waitForExistence(timeout: 5))

        attachScreenshot(app, named: "Cardholder Signup")
    }

    @MainActor
    func testLaunchCardholderDigitalID() throws {
        try requireBackend()
        let app = launchApp()

        // Log into the seeded PWD test account and wait for the ID details to load.
        logIn(app, email: UITestAccounts.cardholderPWD, password: UITestAccounts.password)
        dismissSavePasswordPromptIfShown(app)
        XCTAssertTrue(app.navigationBars[UIText.cardholderHome].waitForExistence(timeout: 15))
        let cardNumber = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "MKT-PWD-2026-00481")).firstMatch
        XCTAssertTrue(cardNumber.waitForExistence(timeout: 10), "Digital ID details did not load")

        attachScreenshot(app, named: "Cardholder Digital ID")
    }

    @MainActor
    func testLaunchMerchantScanner() throws {
        try requireBackend()
        let app = launchApp()

        // Log into the seeded business test account.
        logIn(app, email: UITestAccounts.business, password: UITestAccounts.password)
        dismissSavePasswordPromptIfShown(app)
        XCTAssertTrue(app.navigationBars[UIText.businessHome].waitForExistence(timeout: 15))

        attachScreenshot(app, named: "Merchant Scanner")
    }
}
