//
//  SignupUITests.swift
//  KilalaUITests
//
//  Created by Edson John Willie on 11/6/26.
//
//  Sprint 1 – "Login/Signup UI" (cardholder and business signup screens).
//  UI-10…UI-13 run without the backend. UI-14 needs the backend.
//  UI-15 creates a business account and only runs when
//  TEST_RUNNER_KILALA_ALLOW_WRITE_TESTS=1 is set.
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
        // First, middle, last name and physical card number.
        XCTAssertGreaterThanOrEqual(app.textFields.count, 4, "Expected four text inputs on the signup form")
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

        // First name only is still incomplete. Fields in order: first, middle, last, card number.
        let firstName = app.textFields.element(boundBy: 0)
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

    @MainActor
    private func registerButton(_ app: XCUIApplication) -> XCUIElement {
        // The navigation title and the submit button share the same text; target the button in the form.
        app.collectionViews.buttons[UIText.businessSignupTitle]
    }

    @MainActor
    private func lguPicker(_ app: XCUIApplication) -> XCUIElement {
        app.buttons.containing(NSPredicate(format: "label CONTAINS %@", UIText.makatiOption)).firstMatch
    }

    @MainActor
    private func fillBusinessForm(_ app: XCUIApplication, suffix: String) {
        let values: [(String, String)] = [
            ("Business Name *", "QA iOS Store \(suffix)"),
            ("Business Permit No. *", "QA-IOS-\(suffix)"),
            ("TIN Number *", "000-000-000-000"),
            ("Business Address *", "1 QA Street, Makati City"),
            ("Email Address *", "qa.ios.\(suffix)@example.test")
        ]
        for (placeholder, value) in values {
            let field = app.textFields[placeholder]
            if !field.isHittable { app.swipeUp() }
            field.tap()
            field.typeText(value)
        }
        let password = app.secureTextFields["Password *"]
        if !password.isHittable { app.swipeUp() }
        password.tap()
        password.typeText("QaPassword123!")
        dismissKeyboard(app)
        if !registerButton(app).isHittable { app.swipeUp() }
    }
}
