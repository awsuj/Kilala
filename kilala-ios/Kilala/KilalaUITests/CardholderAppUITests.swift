//
//  CardholderAppUITests.swift
//  KilalaUITests
//
//  Created by Edson John Willie on 11/20/26.
//
//  MCO4 Automation Test Plan – Test-ID CH, iOS Cardholder App (CH-01 – CH-08).
//  Each test follows the plan's steps and expected results. Checks the app does not
//  pass yet are wrapped in `knownIssue(...)` with the finding they belong to
//  (kilala-ios/TESTING.md §8), so they are reported as expected failures.
//
//  CH-03 and the first part of CH-05 run without the backend. The others need the
//  backend on localhost:5001 and are skipped (not failed) when it is not running.
//  CH-08 changes test data and only runs with TEST_RUNNER_KILALA_ALLOW_WRITE_TESTS=1.
//

import XCTest

final class CardholderAppUITests: XCTestCase {

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
            let app = XCUIApplication()
            app.terminate()
            _ = app.wait(for: .notRunning, timeout: 5)
        }
    }

    // MARK: 1. Login and navigation

    /// CH-01 · Cardholder Logs In and Sees Their Digital ID (PWD and Senior Citizen) – Positive
    @MainActor
    func testCH01_CardholderLogsInAndSeesDigitalID() throws {
        try requireBackend()
        let cardholders = [
            (email: UITestAccounts.cardholderPWD, name: UITestAccounts.juanFullName,
             cardLine: "PWD • \(UITestAccounts.juanCardNumber)"),
            (email: UITestAccounts.cardholderSenior, name: UITestAccounts.mariaFullName,
             cardLine: "SENIOR_CITIZEN • \(UITestAccounts.mariaCardNumber)")
        ]

        let app = launchApp()
        for cardholder in cardholders {
            logIn(app, email: cardholder.email, password: UITestAccounts.password)
            dismissSavePasswordPromptIfShown(app)

            XCTAssertTrue(app.navigationBars[UIText.cardholderHome].waitForExistence(timeout: 15),
                          "\(cardholder.email) should land on the Digital ID screen")
            XCTAssertTrue(app.staticTexts[cardholder.name].waitForExistence(timeout: 10),
                          "Digital ID details did not load for \(cardholder.email)")
            XCTAssertTrue(app.staticTexts[UIText.lguBanner].exists, "LGU name missing")
            XCTAssertTrue(app.staticTexts[cardholder.cardLine].exists, "Privilege type and card number missing")
            XCTAssertTrue(app.staticTexts[UIText.statusActive].exists, "Card status missing")
            XCTAssertTrue(app.images.firstMatch.exists, "QR code image missing")
            attachScreenshot(app, named: "CH-01 Digital ID – \(cardholder.email)")

            logOut(app)
        }
    }

    /// CH-02 · Login Rejects a Wrong Password and Stays on the Login Screen – Negative
    @MainActor
    func testCH02_WrongPasswordIsRejected() throws {
        try requireBackend()
        let wrongPassword = "WrongPassword123"
        let app = launchApp()

        logIn(app, email: UITestAccounts.cardholderPWD, password: wrongPassword)

        let anyLoginError = app.staticTexts.matching(
            NSPredicate(format: "label IN %@", [UIText.wrongPasswordError, UIText.currentLoginError])).firstMatch
        XCTAssertTrue(anyLoginError.waitForExistence(timeout: 10), "A login error should be shown")
        knownIssue("F-03", "every login failure shows \"\(UIText.currentLoginError)\"") {
            XCTAssertEqual(anyLoginError.label, UIText.wrongPasswordError)
        }
        XCTAssertTrue(app.buttons[UIText.login].exists, "The app should stay on the login screen")
        XCTAssertFalse(app.navigationBars[UIText.cardholderHome].exists, "A wrong password must not sign in")
        attachScreenshot(app, named: "CH-02 Wrong password")
    }

    /// CH-03 · Login Button Stays Disabled Until Email and Password Are Entered – Negative
    @MainActor
    func testCH03_LoginButtonDisabledUntilBothFieldsFilled() throws {
        let app = launchApp()
        let loginButton = app.buttons[UIText.login]

        // Step 1: both fields empty.
        XCTAssertFalse(loginButton.isEnabled, "Login should be disabled with both fields empty")

        // Step 2: password only.
        let password = app.secureTextFields[UIText.password]
        focus(password, in: app)
        password.typeText(UITestAccounts.password)
        XCTAssertFalse(loginButton.isEnabled, "Login should stay disabled without an email")

        // Step 3: email as well.
        let email = app.textFields[UIText.email]
        focus(email, in: app)
        email.typeText(UITestAccounts.cardholderPWD)
        XCTAssertTrue(loginButton.isEnabled, "Login should be enabled once both fields are filled")
    }

    /// CH-04 · Logging Out or Reopening the App Requires Signing In Again – Positive
    @MainActor
    func testCH04_LogoutAndRelaunchRequireSigningInAgain() throws {
        try requireBackend()
        let app = launchApp()

        // Steps 1–2: log in, then log out.
        logIn(app, email: UITestAccounts.cardholderPWD, password: UITestAccounts.password)
        dismissSavePasswordPromptIfShown(app)
        XCTAssertTrue(app.navigationBars[UIText.cardholderHome].waitForExistence(timeout: 15))
        logOut(app)

        // Step 3: log in again, close the app and reopen it.
        logIn(app, email: UITestAccounts.cardholderPWD, password: UITestAccounts.password)
        dismissSavePasswordPromptIfShown(app)
        XCTAssertTrue(app.navigationBars[UIText.cardholderHome].waitForExistence(timeout: 15))
        app.terminate()
        _ = app.wait(for: .notRunning, timeout: 5)
        app.launch()

        XCTAssertTrue(app.buttons[UIText.login].waitForExistence(timeout: 10),
                      "A reopened app should start on the login screen (the JWT is kept in memory only)")
        XCTAssertFalse(app.navigationBars[UIText.cardholderHome].exists)
    }

    // MARK: 2. Cardholder sign-up

    /// CH-05 · Sign-up Requires Names, Card Number, and a Past Date of Birth – Negative
    @MainActor
    func testCH05_SignupRequiresNamesCardNumberAndPastDateOfBirth() throws {
        let app = launchApp()
        app.buttons[UIText.createAccount].tap()
        let verifyButton = app.buttons[UIText.verifyRecord]
        XCTAssertTrue(verifyButton.waitForExistence(timeout: 5))

        // Step 1: empty form.
        verifyButton.tap()
        XCTAssertTrue(app.staticTexts[UIText.cardholderValidation].waitForExistence(timeout: 3),
                      "An empty form should show the required-fields message")

        // Step 2: names and card number, date of birth left on today.
        let fields = signupFields(app)
        type("Juan", into: fields.first, in: app)
        type("Dela Cruz", into: fields.last, in: app)
        type(UITestAccounts.juanCardNumber, into: fields.cardNumber, in: app)
        dismissKeyboard(app)
        scrollIntoView(verifyButton, in: app)
        verifyButton.tap()
        knownIssue("F-06", "the date of birth defaults to today and is not checked") {
            XCTAssertTrue(app.staticTexts[UIText.dateOfBirthRequired].waitForExistence(timeout: 5),
                          "Leaving the date of birth on today should be rejected")
        }

        // Step 3: future dates can't be picked – the calendar can't move past the current month.
        let picker = app.datePickers.firstMatch
        scrollIntoView(picker, in: app)
        picker.tap()
        let nextMonth = app.buttons["DatePicker.NextMonth"]
        XCTAssertTrue(nextMonth.waitForExistence(timeout: 5), "Calendar did not open")
        knownIssue("F-06", "the date of birth picker accepts future dates") {
            XCTAssertFalse(nextMonth.isEnabled, "The picker should not allow future months")
        }
        attachScreenshot(app, named: "CH-05 Date of birth picker")
    }

    /// CH-06 · Sign-up Details That Match No LGU Record Are Rejected – Negative
    @MainActor
    func testCH06_DetailsThatMatchNoRecordAreRejected() throws {
        try requireBackend()
        let app = launchApp()
        app.buttons[UIText.createAccount].tap()
        XCTAssertTrue(app.buttons[UIText.verifyRecord].waitForExistence(timeout: 5))

        // Step 1: Juan's record, but with the middle name left blank.
        let fields = signupFields(app)
        type("Juan", into: fields.first, in: app)
        type("Dela Cruz", into: fields.last, in: app)
        type(UITestAccounts.juanCardNumber, into: fields.cardNumber, in: app)
        dismissKeyboard(app)
        setDateOfBirth(app, month: "May", year: 1998, day: 14)

        // Step 2.
        let verifyButton = app.buttons[UIText.verifyRecord]
        scrollIntoView(verifyButton, in: app)
        verifyButton.tap()

        let error = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", UIText.noMatchingRecord)).firstMatch
        XCTAssertTrue(error.waitForExistence(timeout: 10), "The no-match message should be shown")
        knownIssue("F-02", "there is no hint that a blank middle name can cause the mismatch") {
            XCTAssertTrue(error.label.contains(UIText.middleNameHint), "Missing middle-name hint: \(error.label)")
        }
        XCTAssertFalse(app.secureTextFields.firstMatch.exists, "The create-login step must not appear")
        attachScreenshot(app, named: "CH-06 No matching record")
    }

    /// CH-07 · Cardholder Verifies Their LGU Record and Creates a Login – Positive
    @MainActor
    func testCH07_CardholderVerifiesRecordAndCreatesLogin() throws {
        try requireBackend()
        try XCTSkipUnless(Self.isUnclaimedRecordAvailable(),
                          "The unclaimed QA record is missing or already claimed – reset it with the SQL in TESTING.md §4.3")
        let app = launchApp()
        app.buttons[UIText.createAccount].tap()
        XCTAssertTrue(app.buttons[UIText.verifyRecord].waitForExistence(timeout: 5))

        // Step 1: verify the unclaimed QA record.
        let fields = signupFields(app)
        type(UnclaimedRecord.firstName, into: fields.first, in: app)
        type(UnclaimedRecord.middleName, into: fields.middle, in: app)
        type(UnclaimedRecord.lastName, into: fields.last, in: app)
        type(UnclaimedRecord.cardNumber, into: fields.cardNumber, in: app)
        dismissKeyboard(app)
        setDateOfBirth(app, month: UnclaimedRecord.birthMonth, year: UnclaimedRecord.birthYear,
                       day: UnclaimedRecord.birthDay)
        let verifyButton = app.buttons[UIText.verifyRecord]
        scrollIntoView(verifyButton, in: app)
        verifyButton.tap()
        XCTAssertTrue(app.staticTexts[UIText.recordFound].waitForExistence(timeout: 10), "Record was not verified")
        // The dialog shows the matched name. The backend leaves middle_name out of its
        // response (F-09), so accept "Ana Santos" as well as "Ana Marie Santos".
        let matchedName = app.staticTexts.matching(NSPredicate(
            format: "label BEGINSWITH %@ AND label ENDSWITH %@",
            UnclaimedRecord.firstName, UnclaimedRecord.lastName)).firstMatch
        XCTAssertTrue(matchedName.exists, "The matched cardholder's name should be shown")
        attachScreenshot(app, named: "CH-07 Record found")

        // Step 2: Proceed opens the create-login step (since PR #43).
        app.buttons[UIText.proceed].tap()
        XCTAssertTrue(app.staticTexts[UIText.createAccountSubtitle].waitForExistence(timeout: 5),
                      "Proceed should open the create-login step")
        XCTAssertEqual(app.textFields.count, 1, "The create-login step should ask for an email")
        XCTAssertEqual(app.secureTextFields.count, 2, "The create-login step should ask for a password and its confirmation")
        XCTAssertTrue(app.buttons[UIText.sendOTP].exists, "The email-code button is missing")
        let createAccount = app.buttons[UIText.createAccountButton]
        XCTAssertTrue(createAccount.exists, "The Create Account button is missing")
        XCTAssertFalse(createAccount.isEnabled, "Create Account must stay disabled until the email is verified")
        XCTAssertTrue(app.staticTexts[UIText.emailMustBeVerified].exists)
        attachScreenshot(app, named: "CH-07 Create login")

        // Step 3 (email code, "Passwords do not match.", then My Kilala ID for Ana) needs the
        // emailed 6-digit code, which a UI test can't read, so it is a manual check (TESTING.md §6).
        // This test claims nothing, so the QA record stays unclaimed.
    }

    // MARK: 3. Digital ID

    /// CH-08 · Revoked Card Shows Its Status on the Digital ID – Negative
    @MainActor
    func testCH08_RevokedCardShowsItsStatus() throws {
        try requireBackend()
        try requireWriteTests()

        // Step 1 (setup): the LGU admin revokes Maria's card; restored after the test.
        let token = try XCTUnwrap(LGUAdminAPI.token(), "LGU admin login failed")
        let record = try XCTUnwrap(LGUAdminAPI.cardholder(cardNumber: UITestAccounts.mariaCardNumber, token: token),
                                   "Maria's card was not found")
        let id = try XCTUnwrap(record["id"] as? String)
        let originalStatus = record["status"] as? String ?? "ACTIVE"
        XCTAssertTrue(LGUAdminAPI.updateCardholder(id: id, fields: ["status": "REVOKED"], token: token))
        addTeardownBlock {
            LGUAdminAPI.updateCardholder(id: id, fields: ["status": originalStatus], token: token)
        }

        // Step 2.
        let app = launchApp()
        logIn(app, email: UITestAccounts.cardholderSenior, password: UITestAccounts.password)
        dismissSavePasswordPromptIfShown(app)
        XCTAssertTrue(app.navigationBars[UIText.cardholderHome].waitForExistence(timeout: 15))

        XCTAssertTrue(app.staticTexts[UIText.statusRevoked].waitForExistence(timeout: 10),
                      "The Digital ID should show the revoked status")
        XCTAssertFalse(app.staticTexts[UIText.statusActive].exists)
        attachScreenshot(app, named: "CH-08 Revoked card")
    }

    // MARK: Helpers

    /// True when POST /api/auth/verify-record accepts the unclaimed QA record.
    private static func isUnclaimedRecordAvailable() -> Bool {
        let url = URL(string: "http://localhost:5001/api/auth/verify-record")!
        let response = sendJSON("POST", url, body: [
            "privilege_type": "PWD",
            "card_id_number": UnclaimedRecord.cardNumber,
            "first_name": UnclaimedRecord.firstName,
            "middle_name": UnclaimedRecord.middleName,
            "last_name": UnclaimedRecord.lastName,
            "date_of_birth": "1999-03-17"
        ])
        return response.status == 200
    }
}
