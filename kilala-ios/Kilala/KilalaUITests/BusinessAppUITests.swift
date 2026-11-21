//
//  BusinessAppUITests.swift
//  KilalaUITests
//
//  Created by Edson John Willie on 11/20/26.
//
//  MCO4 Automation Test Plan – Test-ID BUS, iOS Business App (BUS-01 – BUS-11).
//  Each test follows the plan's steps and expected results. Checks the app does not
//  pass yet are wrapped in `knownIssue(...)` with the finding they belong to
//  (kilala-ios/TESTING.md §8), so they are reported as expected failures.
//
//  All tests need the backend on localhost:5001 and are skipped (not failed) when it is
//  not running. Tests that add or change data (registration, scans, transactions, card
//  status, accreditation) only run with TEST_RUNNER_KILALA_ALLOW_WRITE_TESTS=1, and
//  restore what they change. QR codes are entered in the scanner's Simulator Debug
//  Input, because the simulator has no camera.
//

import XCTest

final class BusinessAppUITests: XCTestCase {

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

    // MARK: 1. Login and registration

    /// BUS-01 · Business User Logs In to the Merchant Scanner and Logs Out – Positive
    /// Since PR #35 the business lands on the Business Dashboard and the Merchant Scanner is
    /// the drawer at its bottom, so the test opens the drawer to reach the scanner.
    @MainActor
    func testBUS01_BusinessLogsInToScannerAndLogsOut() throws {
        try requireBackend()
        let app = openMerchantScanner()
        XCTAssertTrue(app.textFields[UIText.qrDebugInput].exists, "The scanner should be ready for a QR code")
        attachScreenshot(app, named: "BUS-01 Business Dashboard with scanner open")
        logOut(app)
    }

    /// BUS-02 · Business Registration Requires All Required Fields, a Valid Email, and an
    /// 8-Character Password – Negative
    @MainActor
    func testBUS02_RegistrationRequiresValidFields() throws {
        try requireBackend()
        let app = launchApp()
        app.buttons[UIText.registerBusinessLink].tap()
        XCTAssertTrue(lguPicker(app).waitForExistence(timeout: 10),
                      "The LGU list should load and preselect \(UIText.makatiOption)")

        // Step 1: empty form.
        XCTAssertFalse(registerButton(app).isEnabled, "Register Business should be disabled on an empty form")

        // Step 2: every required field, but an invalid email and a short password.
        fillBusinessForm(app, suffix: "bus02", email: "not-an-email", password: "short")
        knownIssue("F-06", "business sign-up has no email format check or password rule") {
            XCTAssertFalse(registerButton(app).isEnabled,
                           "Register Business should stay disabled with an invalid email or short password")
            XCTAssertTrue(app.staticTexts[UIText.invalidEmailHint].exists, "Invalid email hint missing")
            XCTAssertTrue(app.staticTexts[UIText.shortPasswordHint].exists, "Short password hint missing")
        }
        attachScreenshot(app, named: "BUS-02 Invalid email and password")

        // Step 3: correct the email and password (the form is not submitted).
        type("@example.test", into: app.textFields["Email Address *"], in: app)
        type("-password1", into: app.secureTextFields["Password *"], in: app)
        dismissKeyboard(app)
        scrollIntoView(registerButton(app), in: app)
        XCTAssertFalse(app.staticTexts[UIText.invalidEmailHint].exists)
        XCTAssertFalse(app.staticTexts[UIText.shortPasswordHint].exists)
        XCTAssertTrue(registerButton(app).isEnabled, "Register Business should be enabled once everything is valid")
    }

    /// BUS-03 · Register a New Business and Land on the Merchant Scanner – Positive
    @MainActor
    func testBUS03_NewBusinessRegistersAndLandsOnScanner() throws {
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
                      "A newly registered business should be signed in to the Business Dashboard")
        attachScreenshot(app, named: "BUS-03 Registered business")
    }

    // MARK: 2. QR code verification

    /// BUS-04 · Verify an Active Cardholder's QR Code – Positive
    @MainActor
    func testBUS04_VerifyActiveCardholderQRCode() throws {
        try requireBackend()
        try requireWriteTests()   // every recognised scan adds a verification log
        let app = openMerchantScanner()

        verifyQR(app, token: UITestAccounts.juanQRToken)

        XCTAssertTrue(app.navigationBars[UIText.verificationResult].waitForExistence(timeout: 10))
        for text in [UIText.verified, UIText.validCard, UITestAccounts.juanFullName, UITestAccounts.juanCardNumber] {
            XCTAssertTrue(app.staticTexts[text].exists, "\"\(text)\" missing from the result")
        }
        XCTAssertTrue(app.staticTexts[UIText.discountSection].exists, "The discount section should be shown")
        attachScreenshot(app, named: "BUS-04 Verified")
    }

    /// BUS-05 · Unrecognized QR Code Is Flagged as Invalid – Negative
    @MainActor
    func testBUS05_UnrecognizedQRCodeIsFlagged() throws {
        try requireBackend()
        let fakeQR = "KILALA-QR-NOT-A-REAL-CARD"
        let app = openMerchantScanner()

        verifyQR(app, token: fakeQR)

        XCTAssertTrue(app.staticTexts[UIText.noMatchingCardholder].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts[UIText.invalid].exists)
        XCTAssertFalse(app.buttons[UIText.recordTransaction].exists, "No transaction can be recorded")
        attachScreenshot(app, named: "BUS-05 Unrecognized QR")

        app.buttons[UIText.dismissInvalid].tap()
        XCTAssertTrue(app.navigationBars[UIText.verificationResult].waitForNonExistence(timeout: 5),
                      "Dismissing should close the result")
        XCTAssertTrue(app.textFields[UIText.qrDebugInput].exists, "Dismissing should return to the scanner")
    }

    /// BUS-06 · Revoked Card Is Not Accepted – Negative
    @MainActor
    func testBUS06_RevokedCardIsNotAccepted() throws {
        try requireBackend()
        try requireWriteTests()

        // Step 1 (setup): as the LGU admin, create a throwaway QA card and revoke it. A card
        // of its own (not the shared QA record) keeps parallel test runs from interfering.
        let token = try XCTUnwrap(LGUAdminAPI.token(), "LGU admin login failed")
        let card = try XCTUnwrap(LGUAdminAPI.createQACard(expiryDate: LGUAdminAPI.date(daysFromToday: 365), token: token),
                                 "Could not create the QA card")
        XCTAssertTrue(LGUAdminAPI.updateCardholder(id: card.id, fields: ["status": "REVOKED"], token: token))

        // Step 2.
        let app = openMerchantScanner()
        verifyQR(app, token: card.qrToken)

        XCTAssertTrue(app.staticTexts[UIText.revokedReason].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts[UIText.invalid].exists)
        XCTAssertTrue(app.staticTexts["REVOKED"].exists, "Card status should show REVOKED")
        XCTAssertFalse(app.staticTexts[UIText.discountSection].exists, "No discount for a revoked card")
        attachScreenshot(app, named: "BUS-06 Revoked card")
    }

    /// BUS-07 · Expired Card Is Not Accepted – Negative
    @MainActor
    func testBUS07_ExpiredCardIsNotAccepted() throws {
        try requireBackend()
        try requireWriteTests()

        // Step 1 (setup): as the LGU admin, create a throwaway QA card that expired yesterday.
        let token = try XCTUnwrap(LGUAdminAPI.token(), "LGU admin login failed")
        let card = try XCTUnwrap(LGUAdminAPI.createQACard(expiryDate: LGUAdminAPI.date(daysFromToday: -1), token: token),
                                 "Could not create the QA card")

        // Step 2.
        let app = openMerchantScanner()
        verifyQR(app, token: card.qrToken)

        XCTAssertTrue(app.staticTexts[UIText.expiredReason].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts[UIText.invalid].exists)
        XCTAssertTrue(app.staticTexts["EXPIRED"].exists, "Card status should show EXPIRED")
        XCTAssertFalse(app.staticTexts[UIText.discountSection].exists, "No discount for an expired card")
        attachScreenshot(app, named: "BUS-07 Expired card")
    }

    /// BUS-08 · Business With Inactive Accreditation Cannot Verify Cards – Negative
    @MainActor
    func testBUS08_UnaccreditedBusinessCannotVerify() throws {
        try requireBackend()
        try requireWriteTests()

        // Step 1 (setup): turn off Mercury Drug's accreditation; restored after the test.
        let token = try XCTUnwrap(LGUAdminAPI.token(), "LGU admin login failed")
        let business = try XCTUnwrap(LGUAdminAPI.business(named: UITestAccounts.businessName, token: token),
                                     "\(UITestAccounts.businessName) was not found")
        let businessID = try XCTUnwrap(business["id"] as? String)
        let wasAccredited = business["is_accredited"] as? Bool ?? true
        XCTAssertTrue(LGUAdminAPI.setAccreditation(businessID: businessID, accredited: false, token: token))
        addTeardownBlock {
            LGUAdminAPI.setAccreditation(businessID: businessID, accredited: wasAccredited, token: token)
        }

        // Step 2.
        let app = openMerchantScanner()
        verifyQR(app, token: UITestAccounts.juanQRToken)

        XCTAssertTrue(app.staticTexts[UIText.accreditationError].waitForExistence(timeout: 10),
                      "The accreditation error should be shown")
        XCTAssertFalse(app.navigationBars[UIText.verificationResult].exists, "No result sheet should open")
        attachScreenshot(app, named: "BUS-08 Inactive accreditation")
    }

    // MARK: 3. Discounts and transactions

    /// BUS-09 · 20% Discount Is Calculated from the Bill Amount – Positive
    @MainActor
    func testBUS09_DiscountIsCalculatedFromBill() throws {
        try requireBackend()
        try requireWriteTests()   // the scan adds a verification log
        let billAmount = "1234.50"
        let app = openMerchantScanner()
        verifyQR(app, token: UITestAccounts.juanQRToken)
        XCTAssertTrue(app.navigationBars[UIText.verificationResult].waitForExistence(timeout: 10))

        type(billAmount, into: billField(app), in: app)

        for amount in ["₱1234.50", "-₱246.90", "₱987.60"] {
            XCTAssertTrue(app.staticTexts[amount].exists, "\(amount) missing from the discount summary")
        }
        XCTAssertTrue(app.buttons[UIText.recordTransaction].isEnabled, "Record Transaction should be enabled")
        attachScreenshot(app, named: "BUS-09 Discount")
        // Not tapped here: BUS-11 records a transaction.
    }

    /// BUS-10 · Transaction Cannot Be Recorded Without a Valid Bill Amount – Negative
    @MainActor
    func testBUS10_TransactionNeedsValidBillAmount() throws {
        try requireBackend()
        try requireWriteTests()   // the scan adds a verification log
        let invalidAmounts = ["", "0", "."]
        let app = openMerchantScanner()
        verifyQR(app, token: UITestAccounts.juanQRToken)
        XCTAssertTrue(app.navigationBars[UIText.verificationResult].waitForExistence(timeout: 10))

        let field = billField(app)
        scrollIntoView(field, in: app)
        focus(field, in: app)
        for amount in invalidAmounts {
            // The bill field uses a decimal keypad (no Return key), so it stays focused
            // and is cleared with Delete before each value.
            let current = (field.value as? String).flatMap { $0 == UIText.billAmountField ? nil : $0 } ?? ""
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count) + amount)
            XCTAssertFalse(app.buttons[UIText.recordTransaction].isEnabled,
                           "Record Transaction should be disabled for the bill amount \"\(amount)\"")
        }
    }

    /// BUS-11 · Recorded Transaction Appears in the Transaction History – Positive
    @MainActor
    func testBUS11_RecordedTransactionAppearsInHistory() throws {
        try requireBackend()
        try requireWriteTests()   // records a transaction
        let app = openMerchantScanner()
        verifyQR(app, token: UITestAccounts.juanQRToken)
        XCTAssertTrue(app.navigationBars[UIText.verificationResult].waitForExistence(timeout: 10))

        // Step 1.
        type("1234.50", into: billField(app), in: app)
        let record = app.buttons[UIText.recordTransaction]
        scrollIntoView(record, in: app)
        record.tap()

        let alert = app.alerts[UIText.transactionRecorded]
        XCTAssertTrue(alert.waitForExistence(timeout: 10), "The confirmation alert should appear")
        let message = "Successfully recorded bill of ₱1234.50 with a 20% discount (Final: ₱987.60)."
        XCTAssertTrue(alert.staticTexts[message].exists, "Unexpected confirmation message")

        // Step 2. Since PR #35 the history is opened from the dashboard's History button,
        // so the scanner drawer is closed first.
        alert.buttons["OK"].tap()
        XCTAssertTrue(app.navigationBars[UIText.verificationResult].waitForNonExistence(timeout: 5))
        closeScannerDrawer(app)
        let historyLink = app.navigationBars[UIText.businessHome].buttons[UIText.historyButton]
        XCTAssertTrue(historyLink.waitForExistence(timeout: 5), "History button missing")
        historyLink.tap()
        XCTAssertTrue(app.navigationBars[UIText.transactionHistory].waitForExistence(timeout: 10))

        // The history is sorted newest first.
        let newest = app.cells.firstMatch
        XCTAssertTrue(newest.waitForExistence(timeout: 10), "The history should list the new transaction")
        for text in [UITestAccounts.juanFullName, "₱987.60", "Orig: ₱1234.50"] {
            XCTAssertTrue(newest.staticTexts[text].exists, "\"\(text)\" missing from the newest history row")
        }
        attachScreenshot(app, named: "BUS-11 Transaction history")
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
    private func billField(_ app: XCUIApplication) -> XCUIElement {
        app.textFields[UIText.billAmountField]
    }

    @MainActor
    private func fillBusinessForm(_ app: XCUIApplication, suffix: String,
                                  email: String? = nil, password: String = "QaPassword123!") {
        let values: [(String, String)] = [
            ("Business Name *", "QA iOS Store \(suffix)"),
            ("Business Permit No. *", "QA-IOS-\(suffix)"),
            ("TIN Number *", "000-000-000-000"),
            ("Business Address *", "1 QA Street, Makati City"),
            ("Email Address *", email ?? "qa.ios.\(suffix)@example.test")
        ]
        for (placeholder, value) in values {
            type(value, into: app.textFields[placeholder], in: app)
        }
        type(password, into: app.secureTextFields["Password *"], in: app)
        dismissKeyboard(app)
        scrollIntoView(registerButton(app), in: app)
    }
}
