//
//  LoginUITests.swift
//  KilalaUITests
//
//  Created by Edson John Willie on 11/6/26.
//
//  Sprint 1 – "Login/Signup UI" and "JWT Auth API" (login flow).
//  UI-01…UI-04 run without the backend. UI-05…UI-09 need the backend on
//  localhost:5001 and are skipped (not failed) when it is not running.
//

import XCTest

final class LoginUITests: XCTestCase {

    override func setUpWithError() throws {
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // Start every test from the same initial state: portrait orientation.
        // XCTest calls setUp on the main thread, so the main-actor-only XCUIDevice API is safe here.
        MainActor.assumeIsolated {
            XCUIDevice.shared.orientation = .portrait
        }
    }

    override func tearDownWithError() throws {
        // Close the app so the next test starts from a cold launch on the login screen.
        MainActor.assumeIsolated {
            XCUIApplication().terminate()
        }
    }

    // MARK: Offline – layout and client-side validation

    @MainActor
    func testUI01_LoginScreenShowsAllEntryPoints() throws {
        let app = launchApp()

        XCTAssertTrue(app.textFields[UIText.email].exists, "Email field missing")
        XCTAssertTrue(app.secureTextFields[UIText.password].exists, "Password must be a secure field")
        XCTAssertTrue(app.buttons[UIText.login].exists, "Login button missing")
        XCTAssertTrue(app.buttons[UIText.createAccount].exists, "Cardholder signup link missing")
        XCTAssertTrue(app.buttons[UIText.registerBusinessLink].exists, "Business signup link missing")

        attachScreenshot(app, named: "UI-01 Login screen")
    }

    @MainActor
    func testUI02_LoginButtonDisabledUntilBothFieldsFilled() throws {
        let app = launchApp()
        let loginButton = app.buttons[UIText.login]

        XCTAssertFalse(loginButton.isEnabled, "Login should be disabled with both fields empty")

        let emailField = app.textFields[UIText.email]
        emailField.tap()
        emailField.typeText(UITestAccounts.cardholderPWD)
        XCTAssertFalse(loginButton.isEnabled, "Login should be disabled without a password")

        let passwordField = app.secureTextFields[UIText.password]
        passwordField.tap()
        passwordField.typeText(UITestAccounts.password)
        XCTAssertTrue(loginButton.isEnabled, "Login should be enabled once both fields are filled")
    }

    @MainActor
    func testUI03_LoginButtonDisabledWithPasswordOnly() throws {
        let app = launchApp()

        let passwordField = app.secureTextFields[UIText.password]
        passwordField.tap()
        passwordField.typeText(UITestAccounts.password)

        XCTAssertFalse(app.buttons[UIText.login].isEnabled, "Login should be disabled without an email")
    }

    @MainActor
    func testUI04_PasswordIsNotShownInPlainText() throws {
        let app = launchApp()

        let passwordField = app.secureTextFields[UIText.password]
        passwordField.tap()
        passwordField.typeText("secret-value")

        let shownValue = passwordField.value as? String ?? ""
        XCTAssertFalse(shownValue.contains("secret-value"), "Password text is visible on screen")
    }

    // MARK: Live – real login API

    @MainActor
    func testUI05_InvalidCredentialsShowErrorAndStayOnLogin() throws {
        try requireBackend()
        let app = launchApp()

        logIn(app, email: UITestAccounts.cardholderPWD, password: "not-the-password")

        XCTAssertTrue(app.staticTexts[UIText.loginError].waitForExistence(timeout: 10),
                      "Expected the invalid-credentials message")
        XCTAssertTrue(app.buttons[UIText.login].exists, "Should remain on the login screen")
        attachScreenshot(app, named: "UI-05 Invalid credentials")
    }

    @MainActor
    func testUI06_CardholderLogsInToDigitalIDAndLogsOut() throws {
        try requireBackend()
        let app = launchApp()

        logIn(app, email: UITestAccounts.cardholderPWD, password: UITestAccounts.password)
        dismissSavePasswordPromptIfShown(app)

        XCTAssertTrue(app.navigationBars[UIText.cardholderHome].waitForExistence(timeout: 15),
                      "Cardholder should land on the digital ID screen")
        attachScreenshot(app, named: "UI-06 Cardholder home")

        app.buttons[UIText.logout].tap()
        XCTAssertTrue(app.buttons[UIText.login].waitForExistence(timeout: 5),
                      "Logout should return to the login screen")
    }

    @MainActor
    func testUI07_SeniorCitizenLogsInToDigitalID() throws {
        try requireBackend()
        let app = launchApp()

        logIn(app, email: UITestAccounts.cardholderSenior, password: UITestAccounts.password)
        dismissSavePasswordPromptIfShown(app)

        XCTAssertTrue(app.navigationBars[UIText.cardholderHome].waitForExistence(timeout: 15),
                      "Senior citizen should land on the digital ID screen")
    }

    @MainActor
    func testUI08_BusinessLogsInToScannerAndLogsOut() throws {
        try requireBackend()
        let app = launchApp()

        logIn(app, email: UITestAccounts.business, password: UITestAccounts.password)
        dismissSavePasswordPromptIfShown(app)

        XCTAssertTrue(app.navigationBars[UIText.businessHome].waitForExistence(timeout: 15),
                      "Business should land on the merchant scanner")
        attachScreenshot(app, named: "UI-08 Business home")

        app.buttons[UIText.logout].tap()
        XCTAssertTrue(app.buttons[UIText.login].waitForExistence(timeout: 5),
                      "Logout should return to the login screen")
    }

    @MainActor
    func testUI09_LGUAdminIsRedirectedToWebPortal() throws {
        try requireBackend()
        let app = launchApp()

        logIn(app, email: UITestAccounts.lguAdmin, password: UITestAccounts.password)
        dismissSavePasswordPromptIfShown(app)

        XCTAssertTrue(app.staticTexts[UIText.lguAdminNotice].waitForExistence(timeout: 15),
                      "LGU admins should be told to use the web portal")
        attachScreenshot(app, named: "UI-09 LGU admin notice")

        app.buttons[UIText.logout].tap()
        XCTAssertTrue(app.buttons[UIText.login].waitForExistence(timeout: 5),
                      "Logout should return to the login screen")
    }
}
