//
//  KilalaUITestSupport.swift
//  KilalaUITests
//
//  Created by Edson John Willie on 11/6/26.
//
//  Shared helpers for the iOS UI tests that implement the MCO4 Automation Test Plan
//  (CH – iOS Cardholder App, BUS – iOS Business App).
//
//  Tests that need the backend call `try requireBackend()`, which skips the test
//  (XCTSkip) instead of failing when localhost:5001 is not running.
//  Tests that create or change data call `try requireWriteTests()`; they only run when
//  the test runner has KILALA_ALLOW_WRITE_TESTS=1 (set TEST_RUNNER_KILALA_ALLOW_WRITE_TESTS=1
//  in the environment of xcodebuild). See kilala-ios/TESTING.md.
//
//  The app has no accessibility identifiers yet (finding F-05), so elements are found
//  by the text the user sees. All of that text is kept in `UIText`.
//

import XCTest

/// Seeded accounts and records from backend/src/schema/seed.sql (local test data only).
enum UITestAccounts {
    static let password = "MockHashForTestingOnly123456789012"
    static let cardholderPWD = "juan.pwd@email.com"
    static let cardholderSenior = "maria.senior@email.com"
    static let business = "cashier@mercury-mkt.com"
    static let lguAdmin = "admin@makati.gov.ph"

    static let juanCardNumber = "MKT-PWD-2026-00481"
    static let juanFullName = "Juan Santos Dela Cruz"
    static let juanQRToken = "KILALA-QR-MKT-PWD-00481-SECRET"
    static let mariaCardNumber = "MKT-OSCA-2026-08912"
    static let mariaFullName = "Maria Clara Bautista"
    static let businessName = "Mercury Drug"
}

/// The unclaimed QA record in seed.sql, verified by CH-07 (and LIVE-07). No test changes it,
/// because test classes can run in parallel.
enum UnclaimedRecord {
    static let firstName = "Ana"
    static let middleName = "Marie"
    static let lastName = "Santos"
    static let cardNumber = "MKT-PWD-2026-TEST-001"
    static let qrToken = "KILALA-QR-MKT-PWD-TEST-001-SECRET"
    static let birthMonth = "March"
    static let birthYear = 1999
    static let birthDay = 17
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
    /// What the MCO4 plan expects for a wrong password (CH-02). The app currently shows
    /// `currentLoginError` for every failure (finding F-03).
    static let wrongPasswordError = "Invalid email or password"
    static let currentLoginError = "Invalid credentials or server offline."

    // ContentView / post-login screens
    static let cardholderHome = "My Kilala ID"
    /// Since PR #35 a business lands on the dashboard; the scanner is a drawer at the bottom.
    static let businessHome = "Business Dashboard"
    static let scannerDrawerClosed = "Pull Up to Scan QR ID"
    static let scannerDrawerOpen = "QR Verification Scanner"
    static let historyButton = "History"
    static let lguAdminNotice = "Please use the Kilala Web Portal for LGU Admin access."
    static let logout = "Logout"

    // DigitalIDView
    static let lguBanner = "MAKATI CITY"
    static let statusActive = "Status: ACTIVE"
    static let statusRevoked = "Status: REVOKED"

    // CardholderSignupView
    static let cardholderSignupTitle = "Register Account"
    static let verifyRecord = "Verify Record"
    static let cardholderValidation = "Please fill in your first name, last name, and physical card number."
    static let dateOfBirthRequired = "Please select your date of birth."
    static let noMatchingRecord = "No matching LGU record found. Please check your details."
    static let middleNameHint = "If your ID shows a middle name, enter it as well."
    static let verifiedAna = "Verified: Ana Santos!"
    static let passwordsDoNotMatch = "Passwords do not match."
    static let createAccountButton = "Create Account"

    // BusinessSignupView
    static let businessSignupTitle = "Register Business"
    static let makatiOption = "Makati City (MKT)"
    static let invalidEmailHint = "Enter a valid email address, like name@example.com."
    static let shortPasswordHint = "Password must be at least 8 characters."

    // QRScannerView and ScanResultSheet
    static let qrDebugInput = "Paste QR token (e.g. KILALA-QR-...)"
    static let verify = "Verify"
    static let verificationResult = "Verification Result"
    static let verified = "VERIFIED"
    static let invalid = "INVALID / REVOKED"
    static let validCard = "Valid Privilege Card"
    static let noMatchingCardholder = "No Matching Cardholder Record"
    static let revokedReason = "Card status is REVOKED"
    static let expiredReason = "Privilege card has expired"
    static let accreditationError = "Unable to verify QR code. Check your connection or business accreditation."
    static let discountSection = "Apply 20% Statutory Discount"
    static let billAmountField = "Total Bill Amount"
    static let recordTransaction = "Record Transaction"
    static let dismissInvalid = "Dismiss & Scan Again"
    static let transactionRecorded = "Transaction Recorded"
    static let viewHistory = "View Transaction History"
    static let transactionHistory = "Transaction History"
}

extension XCTestCase {

    static let backendHealthURL = URL(string: "http://localhost:5001/api/health")!
    fileprivate static let httpSession = URLSession(configuration: .ephemeral)

    // MARK: Skipping

    /// Skips the current test when the backend is not answering on localhost:5001.
    func requireBackend(file: StaticString = #filePath, line: UInt = #line) throws {
        try XCTSkipUnless(Self.isBackendReachable(),
                          "Backend not reachable on localhost:5001 – start it with `npm run dev` in backend/",
                          file: file, line: line)
    }

    /// Skips the current test unless data-changing tests were explicitly enabled.
    func requireWriteTests(file: StaticString = #filePath, line: UInt = #line) throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["KILALA_ALLOW_WRITE_TESTS"] == "1",
                          "Set TEST_RUNNER_KILALA_ALLOW_WRITE_TESTS=1 to run tests that create or change data",
                          file: file, line: line)
    }

    static func isBackendReachable() -> Bool {
        let response = sendJSON("GET", backendHealthURL)
        return response.status == 200 && (response.json as? [String: Any])?["status"] as? String == "healthy"
    }

    // MARK: Known issues

    /// Runs checks the MCO4 plan expects but the app does not pass yet, for example
    /// behaviour that was proposed in closed PR #41. The failures are reported as
    /// *expected* (linked to the finding), so the suite stays green while the gap stays
    /// visible. When the app is fixed, XCTest reports "expected failure but none
    /// occurred" – that is the signal to remove this wrapper.
    @MainActor
    func knownIssue(_ finding: String, _ reason: String, _ checks: () -> Void) {
        let previous = continueAfterFailure
        continueAfterFailure = true
        XCTExpectFailure("\(finding): \(reason)") { checks() }
        continueAfterFailure = previous
    }

    // MARK: App navigation

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

    /// Fills the login form and taps Login. iOS's "Save Password?" prompt for a previous
    /// login can appear while typing and swallow the text, so the email is checked and the
    /// form refilled once if it didn't stick.
    @MainActor
    func logIn(_ app: XCUIApplication, email: String, password: String,
               file: StaticString = #filePath, line: UInt = #line) {
        let emailField = app.textFields[UIText.email]
        let passwordField = app.secureTextFields[UIText.password]
        dismissSavePasswordPromptIfShown(app, timeout: 1)
        for attempt in 0..<2 {
            replaceText(in: emailField, with: email, app: app)
            focus(passwordField, in: app)
            // Typing into a secure field that already has text replaces it.
            passwordField.typeText(password)
            if (emailField.value as? String) == email { break }
            if attempt == 1 {
                XCTFail("The email didn't stay in the login form", file: file, line: line)
            }
            dismissSavePasswordPromptIfShown(app, timeout: 1)
        }
        app.buttons[UIText.login].tap()
    }

    /// Focuses a text field, deletes whatever it contains and types `text`.
    @MainActor
    func replaceText(in field: XCUIElement, with text: String, app: XCUIApplication) {
        focus(field, in: app)
        let current = field.value as? String ?? ""
        let existing = current == field.placeholderValue ? "" : current
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count) + text)
    }

    /// Taps a text field until it has keyboard focus. Right after launch (or while an iOS
    /// prompt is animating away) the first tap can be lost, which makes typeText fail.
    @MainActor
    func focus(_ element: XCUIElement, in app: XCUIApplication,
               file: StaticString = #filePath, line: UInt = #line) {
        let focused = NSPredicate(format: "hasKeyboardFocus == true")
        for _ in 0..<3 {
            scrollIntoView(element, in: app)
            element.tap()
            let expectation = XCTNSPredicateExpectation(predicate: focused, object: element)
            if XCTWaiter.wait(for: [expectation], timeout: 2) == .completed { return }
            dismissSavePasswordPromptIfShown(app, timeout: 1)
        }
        XCTFail("Could not focus \(element.label.isEmpty ? element.identifier : element.label)", file: file, line: line)
    }

    /// Taps Logout and checks the login screen returns. iOS's "Save Password?" prompt can
    /// appear a few seconds after login and swallow the tap, so it is dismissed and the
    /// tap retried.
    @MainActor
    func logOut(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let logout = app.buttons[UIText.logout]
        for _ in 0..<3 {
            dismissSavePasswordPromptIfShown(app, timeout: 1)
            // On the Business Dashboard an open scanner drawer covers the Logout button.
            if app.staticTexts[UIText.scannerDrawerOpen].exists { closeScannerDrawer(app) }
            _ = logout.waitForExistence(timeout: 3)
            logout.tap()
            if app.buttons[UIText.login].waitForExistence(timeout: 5) { return }
        }
        XCTFail("Logout should return to the login screen", file: file, line: line)
    }

    /// Types into a field. Any open keyboard is closed first: an open keyboard can cover
    /// the next field, and switching fields directly can drop keystrokes.
    @MainActor
    func type(_ text: String, into element: XCUIElement, in app: XCUIApplication) {
        dismissKeyboard(app)
        focus(element, in: app)
        element.typeText(text)
    }

    /// True when the element's centre is on screen and not under the software keyboard.
    /// Unlike `isHittable`, this never throws for rows a List or Form hasn't laid out yet.
    @MainActor
    func isOnScreen(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        guard element.exists else { return false }
        let frame = element.frame
        guard !frame.isEmpty else { return false }
        var visible = app.windows.element(boundBy: 0).frame
        let keyboard = app.keyboards.element
        if keyboard.exists { visible.size.height = keyboard.frame.minY - visible.minY }
        return visible.contains(CGPoint(x: frame.midX, y: frame.midY))
    }

    /// Scrolls (swiping up, or down if the element is above the screen) until the element
    /// is on screen. Fields are filled top to bottom, so a missing row is below.
    @MainActor
    func scrollIntoView(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<6 {
            if isOnScreen(element, in: app) { return }
            if element.exists, !element.frame.isEmpty,
               element.frame.midY < app.windows.element(boundBy: 0).frame.minY {
                app.swipeDown()
            } else {
                app.swipeUp()
            }
        }
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

    /// iOS may offer to save the password after a successful login; dismiss it and let
    /// the prompt finish animating away before the next tap.
    @MainActor
    func dismissSavePasswordPromptIfShown(_ app: XCUIApplication, timeout: TimeInterval = 2) {
        let notNow = app.buttons["Not Now"]
        if notNow.waitForExistence(timeout: timeout) {
            notNow.tap()
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

    // MARK: Cardholder sign-up

    /// The four sign-up text fields in screen order. They have no placeholder or
    /// identifier yet (F-05), so they are found by position.
    @MainActor
    func signupFields(_ app: XCUIApplication) -> (first: XCUIElement, middle: XCUIElement,
                                                  last: XCUIElement, cardNumber: XCUIElement) {
        (app.textFields.element(boundBy: 0), app.textFields.element(boundBy: 1),
         app.textFields.element(boundBy: 2), app.textFields.element(boundBy: 3))
    }

    /// Picks a date in the sign-up date-of-birth picker. The compact picker opens a
    /// calendar; "Show year picker" switches it to month and year wheels.
    @MainActor
    func setDateOfBirth(_ app: XCUIApplication, month: String, year: Int, day: Int,
                        file: StaticString = #filePath, line: UInt = #line) {
        let picker = app.datePickers.firstMatch
        scrollIntoView(picker, in: app)
        picker.tap()

        let showWheels = app.buttons["DatePicker.Show"]
        XCTAssertTrue(showWheels.waitForExistence(timeout: 5), "Calendar did not open", file: file, line: line)
        showWheels.tap()

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

    // MARK: Merchant scanner

    /// Enters a QR token in the scanner's Simulator Debug Input and taps Verify. The
    /// simulator has no camera; this input runs the same verification as a camera scan.
    @MainActor
    func verifyQR(_ app: XCUIApplication, token: String, file: StaticString = #filePath, line: UInt = #line) {
        let input = app.textFields[UIText.qrDebugInput]
        XCTAssertTrue(input.waitForExistence(timeout: 10), "Simulator Debug Input missing", file: file, line: line)
        // iOS's "Save Password?" prompt can appear a few seconds after login and cover the input.
        dismissSavePasswordPromptIfShown(app, timeout: 1)
        type(token, into: input, in: app)
        dismissKeyboard(app)
        app.buttons[UIText.verify].tap()
    }

    /// Logs in as the seeded business, waits for the Business Dashboard and opens the
    /// scanner drawer (tapping its handle), so the Simulator Debug Input is on screen.
    @MainActor
    @discardableResult
    func openMerchantScanner(file: StaticString = #filePath, line: UInt = #line) -> XCUIApplication {
        let app = launchApp()
        logIn(app, email: UITestAccounts.business, password: UITestAccounts.password)
        dismissSavePasswordPromptIfShown(app)
        XCTAssertTrue(app.navigationBars[UIText.businessHome].waitForExistence(timeout: 15),
                      "Business should land on the Business Dashboard", file: file, line: line)
        openScannerDrawer(app, file: file, line: line)
        return app
    }

    /// Opens the dashboard's scanner drawer by tapping its handle.
    @MainActor
    func openScannerDrawer(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let handle = app.staticTexts[UIText.scannerDrawerClosed]
        XCTAssertTrue(handle.waitForExistence(timeout: 10), "Scanner drawer handle missing", file: file, line: line)
        dismissSavePasswordPromptIfShown(app, timeout: 1)
        handle.tap()
        XCTAssertTrue(app.staticTexts[UIText.scannerDrawerOpen].waitForExistence(timeout: 5),
                      "Scanner drawer did not open", file: file, line: line)
        // The handle text changes before the slide-up animation ends; wait until the
        // scanner's input is on screen so the next tap lands where it should.
        let input = app.textFields[UIText.qrDebugInput]
        let deadline = Date().addingTimeInterval(5)
        while !isOnScreen(input, in: app) && Date() < deadline {
            _ = input.waitForExistence(timeout: 0.5)
        }
    }

    /// Closes the scanner drawer by tapping its handle, uncovering the dashboard.
    @MainActor
    func closeScannerDrawer(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let handle = app.staticTexts[UIText.scannerDrawerOpen]
        XCTAssertTrue(handle.waitForExistence(timeout: 5), "Scanner drawer is not open", file: file, line: line)
        // Tap the handle; if a tap is lost (e.g. while the drawer is still settling),
        // drag the handle down instead, as a user would.
        for attempt in 0..<3 {
            if attempt == 0 { handle.tap() } else { handle.swipeDown() }
            if app.staticTexts[UIText.scannerDrawerClosed].waitForExistence(timeout: 3) { return }
            if !handle.exists { break }
        }
        XCTAssertTrue(app.staticTexts[UIText.scannerDrawerClosed].exists,
                      "Scanner drawer did not close", file: file, line: line)
    }

    // MARK: HTTP

    /// Minimal synchronous JSON request for test setup (UI tests run outside the app).
    static func sendJSON(_ method: String, _ url: URL, body: [String: Any]? = nil,
                         bearer: String? = nil) -> (status: Int, json: Any?) {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 5
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        if let bearer { request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization") }

        let semaphore = DispatchSemaphore(value: 0)
        nonisolated(unsafe) var result: (Int, Any?) = (0, nil)
        let task = httpSession.dataTask(with: request) { data, response, _ in
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let json = data.flatMap { try? JSONSerialization.jsonObject(with: $0) }
            result = (status, json)
            semaphore.signal()
        }
        task.resume()
        _ = semaphore.wait(timeout: .now() + 8)
        return result
    }
}

/// LGU admin API calls used to set up and restore test data (CH-08, BUS-06 – BUS-08).
/// Only ever run against the local test backend.
///
/// BUS-06 and BUS-07 create their own throwaway card (card number `MKT-PWD-QA-…`) instead of
/// changing a shared one, so tests running in parallel can't interfere with each other.
enum LGUAdminAPI {
    private static let base = "http://localhost:5001/api"

    private static func url(_ path: String) -> URL { URL(string: base + path)! }

    /// Logs in as the seeded LGU admin and returns the JWT.
    static func token() -> String? {
        let response = XCTestCase.sendJSON("POST", url("/auth/login"),
                                           body: ["email": UITestAccounts.lguAdmin, "password": UITestAccounts.password])
        return (response.json as? [String: Any])?["token"] as? String
    }

    /// The cardholder row (as returned by GET /api/lgu/cardholders) for a card number.
    static func cardholder(cardNumber: String, token: String) -> [String: Any]? {
        let query = cardNumber.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cardNumber
        let response = XCTestCase.sendJSON("GET", url("/lgu/cardholders?search=\(query)"), bearer: token)
        return (response.json as? [[String: Any]])?.first { $0["lgu_id_number"] as? String == cardNumber }
    }

    /// POST /api/lgu/cardholders – creates a throwaway QA card in the admin's LGU and returns
    /// its id and generated QR token.
    static func createQACard(expiryDate: String, token: String) -> (id: String, qrToken: String)? {
        let suffix = String(UUID().uuidString.prefix(8)).uppercased()
        let response = XCTestCase.sendJSON("POST", url("/lgu/cardholders"), body: [
            "lgu_id_number": "MKT-PWD-QA-\(suffix)",
            "first_name": "QA",
            "last_name": "Card \(suffix)",
            "date_of_birth": "1990-01-01",
            "sex": "Female",
            "address": "1 QA Street, Makati City",
            "privilege_type": "PWD",
            "disability_type": "Visual Impairment",
            "expiry_date": expiryDate
        ], bearer: token)
        guard response.status == 201, let row = response.json as? [String: Any],
              let id = row["id"] as? String, let qrToken = row["qr_secret_token"] as? String else { return nil }
        return (id, qrToken)
    }

    /// A date relative to today as yyyy-MM-dd (e.g. -1 for yesterday).
    static func date(daysFromToday days: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Calendar.current.date(byAdding: .day, value: days, to: Date())!)
    }

    /// PATCH /api/lgu/cardholders/{id}; only the given fields change.
    @discardableResult
    static func updateCardholder(id: String, fields: [String: Any], token: String) -> Bool {
        XCTestCase.sendJSON("PATCH", url("/lgu/cardholders/\(id)"), body: fields, bearer: token).status == 200
    }

    /// The business row (as returned by GET /api/lgu/businesses) with the given name.
    static func business(named name: String, token: String) -> [String: Any]? {
        let response = XCTestCase.sendJSON("GET", url("/lgu/businesses"), bearer: token)
        return (response.json as? [[String: Any]])?.first { $0["business_name"] as? String == name }
    }

    /// PATCH /api/lgu/businesses/{id}/accreditation.
    @discardableResult
    static func setAccreditation(businessID: String, accredited: Bool, token: String) -> Bool {
        XCTestCase.sendJSON("PATCH", url("/lgu/businesses/\(businessID)/accreditation"),
                            body: ["is_accredited": accredited], bearer: token).status == 200
    }
}
