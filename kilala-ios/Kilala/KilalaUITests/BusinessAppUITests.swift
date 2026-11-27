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
    /// Since PR #58 the business lands on its dashboard (Home tab), opens the Merchant
    /// Scanner with the floating Scan QR button, and logs out from the Profile tab.
    @MainActor
    func testBUS01_BusinessLogsInToScannerAndLogsOut() throws {
        try requireBackend()
        let app = openMerchantScanner()
        XCTAssertTrue(app.textFields[UIText.qrDebugInput].exists, "The scanner should be ready for a QR code")
        attachScreenshot(app, named: "BUS-01 Merchant Scanner")
        closeScanner(app)
        XCTAssertTrue(app.staticTexts[UIText.businessHome].exists, "Closing the scanner should return to the dashboard")
        logOut(app)
    }

    /// BUS-02 · Business Registration Requires All Required Fields, a Valid Email, and an
    /// 8-Character Password – Negative
    /// Since PR #64 a business signs up by verifying a record its LGU already accredited
    /// (step 1) before creating its login (step 2), so this test also covers the records
    /// that must be refused.
    @MainActor
    func testBUS02_RegistrationRequiresValidFields() throws {
        try requireBackend()
        try requireWriteTests()   // step 2 needs an unclaimed business, created by the LGU admin

        let token = try XCTUnwrap(LGUAdminAPI.token(), "LGU admin login failed")
        let business = try XCTUnwrap(LGUAdminAPI.createUnclaimedBusiness(token: token),
                                     "Could not create the unclaimed QA business")
        let app = launchApp()
        openBusinessSignup(app)
        selectLGU(app)

        // Step 1a: empty form. (The keyboard covers Verify Business while typing, so the
        // filled form is sent with the keyboard's Go key, which runs the same verification.)
        let verifyButton = app.buttons[UIText.verifyBusiness]
        XCTAssertFalse(verifyButton.isEnabled, "Verify Business should be disabled on an empty form")

        // Step 1b: details that match no accredited record.
        fillBusinessVerification(app, name: business.name, permitNo: business.permitNo, tin: "999-999-999-999")
        XCTAssertTrue(verifyButton.isEnabled, "Verify Business should be enabled once every field is filled")
        submitBusinessVerification(app)
        XCTAssertTrue(app.staticTexts[UIText.noMatchingBusiness].waitForExistence(timeout: 10),
                      "A wrong TIN should match no record")

        // Step 1c: a record that is already claimed (Mercury Drug).
        fillBusinessVerification(app, name: UITestAccounts.businessName,
                                 permitNo: UITestAccounts.businessPermitNo, tin: UITestAccounts.businessTIN)
        submitBusinessVerification(app)
        XCTAssertTrue(app.staticTexts[UIText.businessAlreadyClaimed].waitForExistence(timeout: 10),
                      "An already-claimed business must be refused")
        attachScreenshot(app, named: "BUS-02 Already claimed")

        // Step 2: the QA business's record opens the account step.
        fillBusinessVerification(app, name: business.name, permitNo: business.permitNo, tin: business.tin)
        submitBusinessVerification(app)
        XCTAssertTrue(app.staticTexts[UIText.accreditedRecordFound].waitForExistence(timeout: 10),
                      "The QA business should be verified")
        let continueButton = app.buttons[UIText.continueToVerification]
        XCTAssertFalse(continueButton.isEnabled, "Continue should be disabled while the account fields are empty")

        // Step 2a: a short password keeps Continue disabled (rules: 8+ characters,
        // an uppercase letter, a number and a special character).
        // The keyboard stays open from field to field; Return on Confirm Password closes it.
        type("1 QA Street, Makati City", into: app.textFields[UIText.addressField], in: app, closingKeyboard: false)
        type("not-an-email", into: app.textFields[UIText.email], in: app, closingKeyboard: false)
        replaceText(in: app.secureTextFields[UIText.newPasswordField], with: "short", app: app)
        replaceText(in: app.secureTextFields[UIText.confirmPasswordField], with: "short", app: app)
        dismissKeyboard(app)
        scrollIntoView(continueButton, in: app)
        XCTAssertFalse(continueButton.isEnabled, "Continue should stay disabled with a short password")
        attachScreenshot(app, named: "BUS-02 Short password")

        // Step 2b: a valid password with a different confirmation.
        replaceText(in: app.secureTextFields[UIText.newPasswordField], with: "QaPassword123!", app: app)
        replaceText(in: app.secureTextFields[UIText.confirmPasswordField], with: "QaPassword123?", app: app)
        dismissKeyboard(app)
        XCTAssertTrue(app.staticTexts[UIText.passwordsDoNotMatch].waitForExistence(timeout: 3),
                      "A mismatched confirmation should be flagged")
        XCTAssertFalse(continueButton.isEnabled, "Continue should stay disabled while the passwords differ")

        // Step 2c: matching passwords enable Continue, but the invalid email is refused on tap
        // (checked in the app before any code is sent).
        replaceText(in: app.secureTextFields[UIText.confirmPasswordField], with: "QaPassword123!", app: app)
        dismissKeyboard(app)
        scrollIntoView(continueButton, in: app)
        XCTAssertTrue(continueButton.isEnabled, "Continue should be enabled once the passwords match")
        continueButton.tap()
        XCTAssertTrue(app.staticTexts[UIText.invalidEmailError].waitForExistence(timeout: 5),
                      "An invalid email should be refused")
        attachScreenshot(app, named: "BUS-02 Invalid email")
    }

    /// BUS-03 · Register a New Business and Land on the Merchant Scanner – Positive
    /// Since PR #64 a business claims the record its LGU accredited: step 1 verifies it, step 2
    /// creates the login, and an emailed code (OTP) finishes sign-up. A UI test can't read the
    /// email, so this test stops when the account step is ready to send the code; the rest is
    /// manual check M-20 (TESTING.md §6).
    @MainActor
    func testBUS03_NewBusinessRegistersAndLandsOnScanner() throws {
        try requireBackend()
        try requireWriteTests()

        let token = try XCTUnwrap(LGUAdminAPI.token(), "LGU admin login failed")
        let business = try XCTUnwrap(LGUAdminAPI.createUnclaimedBusiness(token: token),
                                     "Could not create the unclaimed QA business")
        let app = launchApp()
        openBusinessSignup(app)

        // Step 1: verify the LGU's record.
        selectLGU(app)
        fillBusinessVerification(app, name: business.name, permitNo: business.permitNo, tin: business.tin)
        XCTAssertTrue(app.buttons[UIText.verifyBusiness].isEnabled, "Verify Business should be enabled")
        submitBusinessVerification(app)
        XCTAssertTrue(app.staticTexts[UIText.accreditedRecordFound].waitForExistence(timeout: 10),
                      "The accredited record should be found")
        XCTAssertTrue(app.staticTexts[business.name].exists, "The matched business name should be shown")
        attachScreenshot(app, named: "BUS-03 Accredited record found")

        // Step 2: account details.
        let suffix = String(UUID().uuidString.prefix(8)).lowercased()
        type("1 QA Street, Makati City", into: app.textFields[UIText.addressField], in: app, closingKeyboard: false)
        type("qa.ios.\(suffix)@example.test", into: app.textFields[UIText.email], in: app, closingKeyboard: false)
        replaceText(in: app.secureTextFields[UIText.newPasswordField], with: "QaPassword123!", app: app)
        replaceText(in: app.secureTextFields[UIText.confirmPasswordField], with: "QaPassword123!", app: app)
        dismissKeyboard(app)
        XCTAssertFalse(app.staticTexts[UIText.passwordsDoNotMatch].exists, "The passwords should match")
        let continueButton = app.buttons[UIText.continueToVerification]
        scrollIntoView(continueButton, in: app)
        XCTAssertTrue(continueButton.isEnabled, "Continue to Verification should be enabled with valid details")
        attachScreenshot(app, named: "BUS-03 Ready for email verification")
        // Not tapped: it emails a code a UI test can't read (manual check M-20).
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
        XCTAssertTrue(app.staticTexts[UIText.notRecognized].exists, "The result should say NOT RECOGNIZED")
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
        // Since PR #58 an expired card has its own status instead of INVALID / REVOKED.
        XCTAssertTrue(app.staticTexts[UIText.expired].exists, "The result should say EXPIRED")
        XCTAssertFalse(app.staticTexts[UIText.verified].exists, "An expired card must not show VERIFIED")
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

        // Step 2. Since PR #58 the history is the Transactions tab, under the scanner.
        alert.buttons["OK"].tap()
        XCTAssertTrue(app.navigationBars[UIText.verificationResult].waitForNonExistence(timeout: 5))
        closeScanner(app)
        app.buttons[UIText.transactionsTab].tap()

        // The list is sorted newest first. Each row reads "name, time, net, From original".
        // Earlier runs left rows with the same amounts, so the newest row must also carry
        // the current time.
        let newest = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@",
                                                      UITestAccounts.juanFullName + ", ")).firstMatch
        XCTAssertTrue(newest.waitForExistence(timeout: 10), "The history should list the new transaction")
        XCTAssertTrue(newest.label.hasSuffix(", ₱987.60, From ₱1234.50"), "Unexpected newest row: \(newest.label)")
        XCTAssertTrue(Self.isRecent(timeIn: newest.label), "The newest row isn't from just now: \(newest.label)")
        attachScreenshot(app, named: "BUS-11 Transaction history")
    }

    // MARK: Helpers

    @MainActor
    private func billField(_ app: XCUIApplication) -> XCUIElement {
        app.textFields[UIText.billAmountField]
    }

    /// True when the time in a history row ("name, 5:32 PM, …") is within a few minutes
    /// of now.
    private static func isRecent(timeIn rowLabel: String) -> Bool {
        let parts = rowLabel.components(separatedBy: ", ")
        guard parts.count > 1 else { return false }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm a"
        guard let rowTime = formatter.date(from: parts[1].replacingOccurrences(of: "\u{202F}", with: " ")) else {
            return false
        }
        let calendar = Calendar.current
        let now = calendar.dateComponents([.hour, .minute], from: Date())
        let row = calendar.dateComponents([.hour, .minute], from: rowTime)
        let minutesNow = (now.hour ?? 0) * 60 + (now.minute ?? 0)
        let minutesRow = (row.hour ?? 0) * 60 + (row.minute ?? 0)
        let difference = abs(minutesNow - minutesRow)
        return min(difference, 24 * 60 - difference) <= 3
    }
}
