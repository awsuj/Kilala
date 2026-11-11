//
//  KilalaUITestSupport.swift
//  KilalaUITests
//
//  Created by Edson John Willie on 11/6/26.
//
//  Sprint 1 QA – shared helpers for the Login/Signup UI tests.
//
//  Tests that need the backend call `try requireBackend()`, which skips the test
//  (XCTSkip) instead of failing when localhost:5001 is not running.
//  Tests that create data call `try requireWriteTests()`; they only run when the
//  test runner has KILALA_ALLOW_WRITE_TESTS=1 (pass it to xcodebuild as
//  TEST_RUNNER_KILALA_ALLOW_WRITE_TESTS=1). See kilala-ios/TESTING.md.
//

import XCTest

/// Seeded accounts from backend/src/schema/seed.sql (local test data only).
enum UITestAccounts {
    static let password = "MockHashForTestingOnly123456789012"
    static let cardholderPWD = "juan.pwd@email.com"
    static let cardholderSenior = "maria.senior@email.com"
    static let business = "cashier@mercury-mkt.com"
    static let lguAdmin = "admin@makati.gov.ph"
}

/// On-screen text the tests rely on. Kept in one place so a copy change in the
/// app only needs one update here.
enum UIText {
    // LoginView
    static let appTitle = "Kilala"
    static let email = "Email"
    static let password = "Password"
    static let login = "Login"
    static let createAccount = "Create new account"
    static let registerBusinessLink = "Register your Business"
    static let loginError = "Invalid credentials or server offline."

    // ContentView / post-login screens
    static let cardholderHome = "My Kilala ID"
    static let businessHome = "Merchant Scanner"
    static let lguAdminNotice = "Please use the Kilala Web Portal for LGU Admin access."
    static let logout = "Logout"

    // CardholderSignupView
    static let cardholderSignupTitle = "Register Account"
    static let matchRecord = "Match your LGU record"
    static let verifyRecord = "Verify Record"
    static let cardholderValidation = "Please fill in your first name, last name, and physical card number."

    // BusinessSignupView
    static let businessSignupTitle = "Register Business"
    static let makatiOption = "Makati City (MKT)"
}

extension XCTestCase {

    static let backendHealthURL = URL(string: "http://localhost:5001/api/health")!
    private static let healthSession = URLSession(configuration: .ephemeral)

    /// Skips the current test when the backend is not answering on localhost:5001.
    func requireBackend(file: StaticString = #filePath, line: UInt = #line) throws {
        try XCTSkipUnless(Self.isBackendReachable(),
                          "Backend not reachable on localhost:5001 – start it with `npm run dev` in backend/",
                          file: file, line: line)
    }

    /// Skips the current test unless data-creating tests were explicitly enabled.
    func requireWriteTests(file: StaticString = #filePath, line: UInt = #line) throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["KILALA_ALLOW_WRITE_TESTS"] == "1",
                          "Set TEST_RUNNER_KILALA_ALLOW_WRITE_TESTS=1 to run tests that create data",
                          file: file, line: line)
    }

    static func isBackendReachable() -> Bool {
        var request = URLRequest(url: backendHealthURL)
        request.timeoutInterval = 3
        let semaphore = DispatchSemaphore(value: 0)
        nonisolated(unsafe) var healthy = false
        let task = healthSession.dataTask(with: request) { data, response, _ in
            // Same check as the unit tests' LiveBackend.isReachable(): an exact "healthy" status.
            if (response as? HTTPURLResponse)?.statusCode == 200,
               let data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               json["status"] as? String == "healthy" {
                healthy = true
            }
            semaphore.signal()
        }
        task.resume()
        _ = semaphore.wait(timeout: .now() + 5)
        return healthy
    }

    /// Launches a fresh copy of the app. The app keeps no session between
    /// launches, so every test starts on the login screen.
    @MainActor
    @discardableResult
    func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts[UIText.appTitle].waitForExistence(timeout: 10),
                      "Login screen did not appear after launch")
        return app
    }

    /// Fills the login form and taps Login.
    @MainActor
    func logIn(_ app: XCUIApplication, email: String, password: String) {
        let emailField = app.textFields[UIText.email]
        emailField.tap()
        emailField.typeText(email)

        let passwordField = app.secureTextFields[UIText.password]
        passwordField.tap()
        passwordField.typeText(password)

        app.buttons[UIText.login].tap()
    }

    /// Closes the software keyboard (if shown) so it cannot cover the next button,
    /// and fails the test if it does not close. Return ends editing in SwiftUI's
    /// single-line text fields. With a hardware keyboard connected no software
    /// keyboard is shown and this does nothing.
    @MainActor
    func dismissKeyboard(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        guard app.keyboards.element.exists else { return }
        app.typeText("\n")
        XCTAssertTrue(app.keyboards.element.waitForNonExistence(timeout: 3),
                      "Software keyboard did not close", file: file, line: line)
    }

    /// iOS may offer to save the password after a successful login; dismiss it.
    @MainActor
    func dismissSavePasswordPromptIfShown(_ app: XCUIApplication) {
        let notNow = app.buttons["Not Now"]
        if notNow.waitForExistence(timeout: 2) {
            notNow.tap()
        }
    }

    /// Attaches a screenshot to the test report (kept even when the test passes),
    /// following the pattern in KilalaUITestsLaunchTests.
    @MainActor
    func attachScreenshot(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
