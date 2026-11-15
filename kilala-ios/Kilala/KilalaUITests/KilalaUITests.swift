//
//  KilalaUITests.swift
//  KilalaUITests
//
//  Created by Joshua Calibo on 10/21/26.
//
//  Sprint 1 – app launch smoke tests. Login and signup flows are covered in
//  LoginUITests.swift and SignupUITests.swift; shared helpers are in
//  Support/KilalaUITestSupport.swift.
//

import XCTest

final class KilalaUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
        // XCTest calls setUp on the main thread, so the main-actor-only XCUIDevice API is safe here.
        MainActor.assumeIsolated {
            XCUIDevice.shared.orientation = .portrait
        }
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        // Close the app so the next test starts from a cold launch.
        MainActor.assumeIsolated {
            XCUIApplication().terminate()
        }
    }

    @MainActor
    func testUI16_AppLaunchesToLoginScreen() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10), "App did not reach the foreground")
        XCTAssertTrue(app.staticTexts[UIText.appTitle].waitForExistence(timeout: 10), "Login screen title missing")
        XCTAssertTrue(app.buttons[UIText.login].exists, "Login button missing")
        // XCUIAutomation Documentation
        // https://developer.apple.com/documentation/xcuiautomation
    }

    @MainActor
    func testUI17_RelaunchStartsSignedOut() throws {
        // The JWT is held in memory only, so a relaunch must ask for credentials again.
        // If the team adds "stay signed in" (e.g. Keychain storage), update this test.
        try requireBackend()
        let app = launchApp()
        logIn(app, email: UITestAccounts.cardholderPWD, password: UITestAccounts.password)
        dismissSavePasswordPromptIfShown(app)
        XCTAssertTrue(app.navigationBars[UIText.cardholderHome].waitForExistence(timeout: 15))

        app.terminate()
        app.launch()

        XCTAssertTrue(app.buttons[UIText.login].waitForExistence(timeout: 10),
                      "A relaunched app should start on the login screen")
        XCTAssertFalse(app.navigationBars[UIText.cardholderHome].exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
