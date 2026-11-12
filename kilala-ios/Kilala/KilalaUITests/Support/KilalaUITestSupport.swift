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
    static let loginError = "Invalid email or password"

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
    static let dateOfBirthRequired = "Please select your date of birth."
    static let noMatchingRecord = "No matching LGU record found. Please check your details."
    static let middleNameHint = "If your ID shows a middle name, enter it as well."
    static let passwordsDoNotMatch = "Passwords do not match."

    // BusinessSignupView
    static let businessSignupTitle = "Register Business"
    static let makatiOption = "Makati City (MKT)"
    static let invalidEmailHint = "Enter a valid email address, like name@example.com."
    static let shortPasswordHint = "Password must be at least 8 characters."
}

/// Accessibility identifiers set in the app's views (F-05). Prefer these over visible
/// text when locating inputs; visible text is still used to check what the user sees.
enum UIID {
    // LoginView
    static let loginEmail = "login.email"
    static let loginPassword = "login.password"
    static let loginSubmit = "login.submit"
    static let loginError = "login.error"
    static let createAccountLink = "login.createAccount"
    static let registerBusinessLink = "login.registerBusiness"

    // CardholderSignupView – step 1, match the LGU record
    static let typePWD = "signup.type.pwd"
    static let typeSenior = "signup.type.senior"
    static let firstName = "signup.firstName"
    static let middleName = "signup.middleName"
    static let lastName = "signup.lastName"
    static let cardNumber = "signup.cardNumber"
    static let dateOfBirth = "signup.dateOfBirth"
    static let verify = "signup.verify"
    static let signupError = "signup.error"
    static let verified = "signup.verified"

    // CardholderSignupView – step 2, create the login (F-01)
    static let signupEmail = "signup.email"
    static let signupPassword = "signup.password"
    static let signupConfirmPassword = "signup.confirmPassword"
    static let signupCreateAccount = "signup.createAccount"
    static let signupAccountError = "signup.accountError"

    // BusinessSignupView
    static let businessName = "business.name"
    static let businessPermit = "business.permit"
    static let businessTIN = "business.tin"
    static let businessAddress = "business.address"
    static let businessEmail = "business.email"
    static let businessPassword = "business.password"
    static let businessSubmit = "business.submit"
    static let businessEmailHint = "business.emailHint"
    static let businessPasswordHint = "business.passwordHint"

    // DigitalIDView
    static let digitalIDName = "digitalID.name"
    static let digitalIDStatus = "digitalID.status"
}

/// The unclaimed LGU record used by the cardholder sign-up tests (backend/src/schema/seed.sql).
enum UnclaimedRecordUI {
    static let firstName = "Ana"
    static let middleName = "Marie"
    static let lastName = "Santos"
    static let cardNumber = "MKT-PWD-2026-TEST-001"
    static let birthMonth = "March"
    static let birthYear = 1999
    static let birthDay = 17
    static let birthDateISO = "1999-03-17"
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
        let emailField = app.textFields[UIID.loginEmail]
        emailField.tap()
        emailField.typeText(email)

        let passwordField = app.secureTextFields[UIID.loginPassword]
        passwordField.tap()
        passwordField.typeText(password)

        app.buttons[UIID.loginSubmit].tap()
    }

    /// Types into a field. Any open keyboard is closed first: switching straight from one
    /// field to another can drop keystrokes while the keyboard changes layout (for example
    /// email → password), and an open keyboard can cover the next field.
    @MainActor
    func type(_ text: String, into element: XCUIElement, in app: XCUIApplication) {
        dismissKeyboard(app)
        if !element.isHittable { app.swipeUp() }
        element.tap()
        element.typeText(text)
    }

    /// Taps Logout and checks the login screen returns. iOS's "Save Password?" prompt can
    /// appear a few seconds after login and swallow the tap, so it is dismissed and the tap
    /// retried once.
    @MainActor
    func logOut(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let logout = app.buttons[UIText.logout]
        for _ in 0..<3 {
            dismissSavePasswordPromptIfShown(app, timeout: 1)
            // A tap during the prompt's dismiss animation lands nowhere, so wait until
            // the button can actually be tapped.
            waitUntilHittable(logout, timeout: 3)
            logout.tap()
            if app.buttons[UIID.loginSubmit].waitForExistence(timeout: 5) { return }
        }
        XCTFail("Logout should return to the login screen", file: file, line: line)
    }

    /// Waits (up to `timeout`) until the element can receive a tap; returns whether it can.
    @MainActor
    @discardableResult
    func waitUntilHittable(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == true"),
                                                    object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    /// Picks a date in the cardholder sign-up date-of-birth picker. The compact picker
    /// opens a calendar; "Show year picker" switches it to month and year wheels.
    @MainActor
    func setDateOfBirth(_ app: XCUIApplication, month: String, year: Int, day: Int,
                        file: StaticString = #filePath, line: UInt = #line) {
        let picker = app.datePickers[UIID.dateOfBirth]
        if !picker.isHittable { app.swipeUp() }
        picker.tap()

        let yearToggle = app.buttons["DatePicker.Show"]
        XCTAssertTrue(yearToggle.waitForExistence(timeout: 5), "Calendar did not open", file: file, line: line)
        yearToggle.tap()

        let monthWheel = app.pickerWheels.element(boundBy: 0)
        XCTAssertTrue(monthWheel.waitForExistence(timeout: 5), "Month/year wheels did not appear", file: file, line: line)
        monthWheel.adjust(toPickerWheelValue: month)
        app.pickerWheels.element(boundBy: 1).adjust(toPickerWheelValue: String(year))
        // While the wheels are shown, the same toggle is identified as "DatePicker.Hide".
        app.buttons["DatePicker.Hide"].tap()

        let dayButton = app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", "\(month) \(day)")).firstMatch
        XCTAssertTrue(dayButton.waitForExistence(timeout: 5), "Day \(month) \(day) not shown", file: file, line: line)
        dayButton.tap()

        let dismiss = app.buttons["PopoverDismissRegion"]
        if dismiss.waitForExistence(timeout: 2) { dismiss.tap() }
    }

    /// True when the unclaimed seed record can still be claimed. Sign-up tests that claim it
    /// skip otherwise; reset it with the SQL in kilala-ios/TESTING.md §4.
    static func isUnclaimedRecordAvailable() -> Bool {
        var request = URLRequest(url: URL(string: "http://localhost:5001/api/auth/verify-record")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 3
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "privilege_type": "PWD",
            "card_id_number": UnclaimedRecordUI.cardNumber,
            "first_name": UnclaimedRecordUI.firstName,
            "middle_name": UnclaimedRecordUI.middleName,
            "last_name": UnclaimedRecordUI.lastName,
            "date_of_birth": UnclaimedRecordUI.birthDateISO
        ])
        let semaphore = DispatchSemaphore(value: 0)
        nonisolated(unsafe) var available = false
        let task = healthSession.dataTask(with: request) { _, response, _ in
            available = (response as? HTTPURLResponse)?.statusCode == 200
            semaphore.signal()
        }
        task.resume()
        _ = semaphore.wait(timeout: .now() + 5)
        return available
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
    func dismissSavePasswordPromptIfShown(_ app: XCUIApplication, timeout: TimeInterval = 2) {
        let notNow = app.buttons["Not Now"]
        if notNow.waitForExistence(timeout: timeout) {
            notNow.tap()
            // Let the prompt finish animating away before the next tap.
            _ = notNow.waitForNonExistence(timeout: 3)
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
