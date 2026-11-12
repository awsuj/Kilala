//
//  SignupUITests.swift
//  KilalaUITests
//
//  Created by Edson John Willie on 11/6/26.
//
//  Sprint 1 – "Login/Signup UI" (cardholder and business signup screens).
//  UI-10…UI-13 and UI-18 run without the backend. UI-14, UI-19 and UI-21 need the backend.
//  UI-15 (creates a business account) and UI-20 (claims the unclaimed seed record) only
//  run when TEST_RUNNER_KILALA_ALLOW_WRITE_TESTS=1 is set.
//  UI-18…UI-21 cover the fixes for findings F-01, F-02 and F-06 (kilala-ios/TESTING.md §8).
//

import XCTest

final class SignupUITests: XCTestCase {

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

    // MARK: Cardholder signup (verify LGU record)

    @MainActor
    func testUI10_CreateAccountOpensCardholderSignup() throws {
        let app = launchApp()

        app.buttons[UIText.createAccount].tap()

        XCTAssertTrue(app.staticTexts[UIText.cardholderSignupTitle].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts[UIText.matchRecord].exists)
        XCTAssertTrue(app.buttons["PWD"].exists, "PWD ID type option missing")
        XCTAssertTrue(app.buttons["Senior Citizen"].exists, "Senior Citizen ID type option missing")
        XCTAssertTrue(app.buttons[UIText.verifyRecord].exists)
        for field in [UIID.firstName, UIID.middleName, UIID.lastName, UIID.cardNumber] {
            XCTAssertTrue(app.textFields[field].exists, "\(field) input missing")
        }
        XCTAssertTrue(app.datePickers[UIID.dateOfBirth].exists, "Date of birth picker missing")
        attachScreenshot(app, named: "UI-10 Cardholder signup")
    }

    @MainActor
    func testUI11_CardholderSignupRequiresNamesAndCardNumber() throws {
        let app = launchApp()
        app.buttons[UIText.createAccount].tap()
        XCTAssertTrue(app.buttons[UIText.verifyRecord].waitForExistence(timeout: 5))

        // Empty form.
        app.buttons[UIText.verifyRecord].tap()
        XCTAssertTrue(app.staticTexts[UIText.cardholderValidation].waitForExistence(timeout: 3),
                      "Empty form should show the required-fields message")

        // First name only is still incomplete.
        let firstName = app.textFields[UIID.firstName]
        firstName.tap()
        firstName.typeText("Juan")
        dismissKeyboard(app)
        app.buttons[UIText.verifyRecord].tap()
        XCTAssertTrue(app.staticTexts[UIText.cardholderValidation].waitForExistence(timeout: 3),
                      "Missing last name and card number should still be rejected")
        attachScreenshot(app, named: "UI-11 Cardholder validation")
    }

    @MainActor
    func testUI12_CardholderSignupCanReturnToLogin() throws {
        let app = launchApp()
        app.buttons[UIText.createAccount].tap()
        XCTAssertTrue(app.staticTexts[UIText.cardholderSignupTitle].waitForExistence(timeout: 5))

        app.navigationBars.buttons.element(boundBy: 0).tap()

        XCTAssertTrue(app.buttons[UIText.login].waitForExistence(timeout: 5),
                      "Back should return to the login screen")
    }

    // MARK: Cardholder signup fixes (F-01, F-02, F-06)

    @MainActor
    func testUI18_CardholderSignupRequiresAPastDateOfBirth() throws {
        // F-06: the picker starts on today and used to accept any date.
        let app = launchApp()
        app.buttons[UIText.createAccount].tap()
        XCTAssertTrue(app.buttons[UIText.verifyRecord].waitForExistence(timeout: 5))

        type("Juan", into: app.textFields[UIID.firstName], in: app)
        type("Dela Cruz", into: app.textFields[UIID.lastName], in: app)
        type("MKT-PWD-2026-00481", into: app.textFields[UIID.cardNumber], in: app)
        dismissKeyboard(app)
        app.buttons[UIText.verifyRecord].tap()
        let error = app.staticTexts[UIID.signupError]
        XCTAssertTrue(error.waitForExistence(timeout: 3))
        XCTAssertEqual(error.label, UIText.dateOfBirthRequired, "Leaving the date of birth on today should be rejected")

        // Future dates can't be chosen: the calendar can't move past the current month.
        app.datePickers[UIID.dateOfBirth].tap()
        let nextMonth = app.buttons["DatePicker.NextMonth"]
        XCTAssertTrue(nextMonth.waitForExistence(timeout: 5))
        XCTAssertFalse(nextMonth.isEnabled, "The date of birth picker should not allow future months")
        attachScreenshot(app, named: "UI-18 Date of birth limits")
    }

    @MainActor
    func testUI19_BlankMiddleNameShowsMiddleNameHint() throws {
        // F-02: Juan's record has a middle name, so a blank middle name can't match it.
        try requireBackend()
        let app = launchApp()
        app.buttons[UIText.createAccount].tap()
        XCTAssertTrue(app.buttons[UIText.verifyRecord].waitForExistence(timeout: 5))

        type("Juan", into: app.textFields[UIID.firstName], in: app)
        type("Dela Cruz", into: app.textFields[UIID.lastName], in: app)
        type("MKT-PWD-2026-00481", into: app.textFields[UIID.cardNumber], in: app)
        dismissKeyboard(app)
        setDateOfBirth(app, month: "May", year: 1998, day: 14)
        app.buttons[UIText.verifyRecord].tap()

        let error = app.staticTexts[UIID.signupError]
        XCTAssertTrue(error.waitForExistence(timeout: 10), "Expected an error message")
        XCTAssertTrue(error.label.contains(UIText.noMatchingRecord), "Unexpected message: \(error.label)")
        XCTAssertTrue(error.label.contains(UIText.middleNameHint), "Missing middle-name hint: \(error.label)")
        attachScreenshot(app, named: "UI-19 Middle name hint")
    }

    @MainActor
    func testUI20_CardholderSignupCreatesLoginAndOpensDigitalID() throws {
        // F-01: after the record is verified the user creates a login, which calls
        // POST /api/auth/claim-cardholder, and lands on their Digital ID.
        try requireBackend()
        try requireWriteTests()
        try XCTSkipUnless(Self.isUnclaimedRecordAvailable(),
                          "The unclaimed seed record is already claimed – reset it with the SQL in TESTING.md §4")
        let app = launchApp()
        app.buttons[UIText.createAccount].tap()
        XCTAssertTrue(app.buttons[UIText.verifyRecord].waitForExistence(timeout: 5))

        type(UnclaimedRecordUI.firstName, into: app.textFields[UIID.firstName], in: app)
        type(UnclaimedRecordUI.middleName, into: app.textFields[UIID.middleName], in: app)
        type(UnclaimedRecordUI.lastName, into: app.textFields[UIID.lastName], in: app)
        type(UnclaimedRecordUI.cardNumber, into: app.textFields[UIID.cardNumber], in: app)
        dismissKeyboard(app)
        setDateOfBirth(app, month: UnclaimedRecordUI.birthMonth, year: UnclaimedRecordUI.birthYear,
                       day: UnclaimedRecordUI.birthDay)
        app.buttons[UIText.verifyRecord].tap()

        XCTAssertTrue(app.staticTexts[UIID.verified].waitForExistence(timeout: 10), "Record was not verified")
        let email = app.textFields[UIID.signupEmail]
        XCTAssertTrue(email.waitForExistence(timeout: 5), "Create-login step did not appear")

        let suffix = String(UUID().uuidString.prefix(8)).lowercased()
        type("qa.ios.claim.\(suffix)@example.test", into: email, in: app)

        // When Password is focused while both password fields are empty, iOS replaces the
        // keyboard with its "Use Strong Password?" sheet, which XCUITest can't operate.
        // Filling Confirm Password first avoids it (see TESTING.md §9). The confirmation is
        // deliberately different, to check the mismatch message.
        let password = app.secureTextFields[UIID.signupPassword]
        let confirm = app.secureTextFields[UIID.signupConfirmPassword]
        typeSecure("QaPassword999!", into: confirm, in: app)
        typeSecure("QaPassword123!", into: password, in: app)

        // A mismatched confirmation is caught before anything is sent.
        let createButton = app.buttons[UIID.signupCreateAccount]
        if !createButton.isHittable { app.swipeUp() }
        createButton.tap()
        let accountError = app.staticTexts[UIID.signupAccountError]
        XCTAssertTrue(accountError.waitForExistence(timeout: 3))
        XCTAssertEqual(accountError.label, UIText.passwordsDoNotMatch)

        // Retyping a secure field replaces its contents.
        typeSecure("QaPassword123!", into: confirm, in: app)
        if !createButton.isHittable { app.swipeUp() }
        createButton.tap()
        dismissSavePasswordPromptIfShown(app)

        XCTAssertTrue(app.navigationBars[UIText.cardholderHome].waitForExistence(timeout: 15),
                      "A new cardholder should be signed in to their Digital ID")
        let name = app.staticTexts[UIID.digitalIDName]
        XCTAssertTrue(name.waitForExistence(timeout: 10))
        XCTAssertEqual(name.label, "Ana Marie Santos", "The Digital ID should belong to the claimed record")
        attachScreenshot(app, named: "UI-20 New cardholder Digital ID")
    }

    // MARK: Business signup

    @MainActor
    func testUI13_BusinessSignupShowsFormWithSubmitDisabled() throws {
        let app = launchApp()

        app.buttons[UIText.registerBusinessLink].tap()

        XCTAssertTrue(app.navigationBars[UIText.businessSignupTitle].waitForExistence(timeout: 5))
        for placeholder in ["Business Name *", "Branch Name (Optional)", "Business Permit No. *",
                            "TIN Number *", "Business Address *", "Email Address *"] {
            XCTAssertTrue(app.textFields[placeholder].exists, "\(placeholder) field missing")
        }
        XCTAssertTrue(app.secureTextFields["Password *"].exists, "Password must be a secure field")
        XCTAssertFalse(registerButton(app).isEnabled, "Register should be disabled on an empty form")
        attachScreenshot(app, named: "UI-13 Business signup")
    }

    @MainActor
    func testUI14_BusinessSignupLoadsLGUsAndEnablesSubmitWhenComplete() throws {
        try requireBackend()
        let app = launchApp()
        app.buttons[UIText.registerBusinessLink].tap()

        XCTAssertTrue(lguPicker(app).waitForExistence(timeout: 10),
                      "LGU list should load from the backend and preselect Makati City (MKT)")

        fillBusinessForm(app, suffix: "ui14")
        XCTAssertTrue(registerButton(app).isEnabled, "Register should be enabled once required fields are filled")
        attachScreenshot(app, named: "UI-14 Business form complete")
        // Not submitted: UI-15 covers submission behind the write-test flag.
    }

    @MainActor
    func testUI21_BusinessSignupRejectsInvalidEmailAndShortPassword() throws {
        // F-06: business sign-up had no email format check and no password rule.
        try requireBackend()
        let app = launchApp()
        app.buttons[UIText.registerBusinessLink].tap()
        XCTAssertTrue(lguPicker(app).waitForExistence(timeout: 10))

        fillBusinessForm(app, suffix: "ui21", email: "not-an-email", password: "short")
        XCTAssertEqual(app.staticTexts[UIID.businessEmailHint].label, UIText.invalidEmailHint, "Invalid email hint missing")
        XCTAssertEqual(app.staticTexts[UIID.businessPasswordHint].label, UIText.shortPasswordHint, "Short password hint missing")
        XCTAssertFalse(registerButton(app).isEnabled, "Register must stay disabled with an invalid email or password")
        attachScreenshot(app, named: "UI-21 Business validation")

        // Fixing both enables Register (the form is not submitted).
        type("@example.test", into: app.textFields[UIID.businessEmail], in: app)
        type("-password1", into: app.secureTextFields[UIID.businessPassword], in: app)
        dismissKeyboard(app)
        if !registerButton(app).isHittable { app.swipeUp() }
        XCTAssertFalse(app.staticTexts[UIID.businessEmailHint].exists)
        XCTAssertFalse(app.staticTexts[UIID.businessPasswordHint].exists)
        XCTAssertTrue(registerButton(app).isEnabled, "Register should be enabled once the email and password are valid")
    }

    @MainActor
    func testUI15_BusinessRegistrationLogsInToScanner() throws {
        try requireBackend()
        try requireWriteTests()
        let app = launchApp()
        app.buttons[UIText.registerBusinessLink].tap()
        XCTAssertTrue(lguPicker(app).waitForExistence(timeout: 10))

        let suffix = String(UUID().uuidString.prefix(8)).lowercased()
        fillBusinessForm(app, suffix: suffix)
        registerButton(app).tap()
        dismissSavePasswordPromptIfShown(app)

        XCTAssertTrue(app.navigationBars[UIText.businessHome].waitForExistence(timeout: 15),
                      "A newly registered business should be signed in to the scanner")
        attachScreenshot(app, named: "UI-15 Registered business home")
    }

    // MARK: Helpers

    /// Types into a secure field and checks that a real keyboard appeared and that every
    /// character arrived (secure fields report one bullet per character).
    @MainActor
    private func typeSecure(_ text: String, into field: XCUIElement, in app: XCUIApplication,
                            file: StaticString = #filePath, line: UInt = #line) {
        dismissKeyboard(app)
        if !field.isHittable { app.swipeUp() }
        field.tap()
        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 3),
                      "No keyboard for \(field.identifier) – iOS may be showing its strong-password sheet",
                      file: file, line: line)
        field.typeText(text)
        XCTAssertEqual((field.value as? String)?.count, text.count,
                       "Some characters were not typed into \(field.identifier)", file: file, line: line)
        dismissKeyboard(app)
    }

    @MainActor
    private func registerButton(_ app: XCUIApplication) -> XCUIElement {
        // The navigation title and the submit button share the same text, so use the button's identifier.
        app.buttons[UIID.businessSubmit]
    }

    @MainActor
    private func lguPicker(_ app: XCUIApplication) -> XCUIElement {
        app.buttons.containing(NSPredicate(format: "label CONTAINS %@", UIText.makatiOption)).firstMatch
    }

    @MainActor
    private func fillBusinessForm(_ app: XCUIApplication, suffix: String,
                                  email: String? = nil, password: String = "QaPassword123!") {
        let values: [(String, String)] = [
            (UIID.businessName, "QA iOS Store \(suffix)"),
            (UIID.businessPermit, "QA-IOS-\(suffix)"),
            (UIID.businessTIN, "000-000-000-000"),
            (UIID.businessAddress, "1 QA Street, Makati City"),
            (UIID.businessEmail, email ?? "qa.ios.\(suffix)@example.test")
        ]
        for (identifier, value) in values {
            type(value, into: app.textFields[identifier], in: app)
        }
        type(password, into: app.secureTextFields[UIID.businessPassword], in: app)
        dismissKeyboard(app)
        if !registerButton(app).isHittable { app.swipeUp() }
    }
}
