//
//  KilalaTests.swift
//  KilalaTests
//
//  Created by Joshua Calibo on 10/21/26.
//

import Foundation
import Testing
@testable import Kilala

/// Sprint 1 – app foundation checks: configuration the login, signup and scanner
/// flows depend on. Runs offline inside the Kilala test host.
///
/// The other Sprint 1 suites live next to this file:
/// - ModelContractTests        (S1-API)  agreed JSON ↔ Codable models
/// - SchemaContractTests       (S1-SCH)  app enums ↔ backend/src/schema/schema.sql
/// - APIServiceAuthTests       (S1-JWT)  APIService against a stubbed backend
/// - LiveBackendContractTests  (S1-LIVE) APIService against the real backend
///
/// Swift Testing Documentation
/// https://developer.apple.com/documentation/testing
@Suite("S1-APP · App foundation")
struct KilalaTests {

    private var info: [String: Any] { Bundle.main.infoDictionary ?? [:] }

    @Test("APP-01 Tests run inside the Kilala app host")
    func testHostIsKilalaApp() {
        #expect(Bundle.main.object(forInfoDictionaryKey: "CFBundleExecutable") as? String == "Kilala")
    }

    @Test("APP-02 App Transport Security allows plain HTTP to the local backend")
    func transportSecurityAllowsLocalBackend() throws {
        // APIService calls http://localhost:5001/api. Without an ATS exception
        // iOS blocks every login and signup request before it leaves the device.
        let ats = try #require(info["NSAppTransportSecurity"] as? [String: Any],
                               "NSAppTransportSecurity is missing from Info.plist")
        let allowsArbitraryLoads = ats["NSAllowsArbitraryLoads"] as? Bool ?? false
        let allowsLocalNetworking = ats["NSAllowsLocalNetworking"] as? Bool ?? false
        #expect(allowsArbitraryLoads || allowsLocalNetworking)
    }

    @Test("APP-03 Camera usage description is present for the QR scanner")
    func cameraUsageDescriptionIsPresent() throws {
        // Without this key iOS terminates the app the first time the business
        // scanner asks for the camera.
        let description = try #require(info["NSCameraUsageDescription"] as? String,
                                       "NSCameraUsageDescription is missing from Info.plist")
        #expect(!description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
}
