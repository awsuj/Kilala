//
//  KilalaUITests.swift
//  KilalaUITests
//
//  Created by Joshua Calibo on 10/21/26.
//
//  Supporting smoke tests (not in the MCO4 plan): the app launches to the login
//  screen, LGU admins are sent to the web portal, and launch time is measured.
//  The planned test cases are in CardholderAppUITests.swift (CH-01 – CH-08) and
//  BusinessAppUITests.swift (BUS-01 – BUS-11); shared helpers are in
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
            let app = XCUIApplication()
            app.terminate()
            _ = app.wait(for: .notRunning, timeout: 5)
        }
    }

    @MainActor
    func testAppLaunchesToLoginScreen() throws {
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
    func testLGUAdminIsDirectedToWebPortal() throws {
        // LGU admins have no screens in the app; they are told to use the web portal.
        try requireBackend()
        let app = launchApp()
        logIn(app, email: UITestAccounts.lguAdmin, password: UITestAccounts.password)
        dismissSavePasswordPromptIfShown(app)

        XCTAssertTrue(app.staticTexts[UIText.lguAdminNotice].waitForExistence(timeout: 15),
                      "LGU admins should be told to use the web portal")
        logOut(app)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
