//
//  APIServiceAuthTests.swift
//  KilalaTests
//
//  Created by Edson John Willie on 11/6/26.
//
//  Sprint 1 – "JWT Auth API" and "Finalize API agreements" (client side).
//  Exercises APIService against stubbed HTTP responses (MockURLProtocol):
//  request shape, token handling and error mapping. Runs offline.
//

import Foundation
import Testing
@testable import Kilala

/// Parent for every suite that goes through `URLSession.shared` (mocked or live).
/// `.serialized` here makes the nested suites run one after the other, and each nested
/// suite is also marked `.serialized` so its own tests run one at a time. Together this
/// guarantees a stub installed by one test never answers a request from another test,
/// and that tests sharing `APIService.shared.authToken` never overlap.
@MainActor
@Suite("Network-dependent tests", .serialized)
struct NetworkTests {}

extension NetworkTests {

    @MainActor
    @Suite("S1-JWT/S1-API · APIService with stubbed backend", .serialized)
    struct APIServiceAuthTests {

        private let api = APIService.shared

        init() {
            APIService.shared.authToken = nil
        }

        // MARK: Login

        @Test("AUTH-01 login sends POST /api/auth/login with a JSON email and password")
        func loginRequestShape() async throws {
            MockURLProtocol.respond(status: 200, json: Fixtures.loginSuccess(role: "CARDHOLDER"))
            defer { MockURLProtocol.uninstall() }

            _ = try await api.login(email: TestAccounts.cardholderPWD, password: TestAccounts.password)

            let request = try #require(MockURLProtocol.lastRequest)
            #expect(request.httpMethod == "POST")
            #expect(request.url?.absoluteString == "http://localhost:5001/api/auth/login")
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
            #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
            #expect(request.jsonBody["email"] as? String == TestAccounts.cardholderPWD)
            #expect(request.jsonBody["password"] as? String == TestAccounts.password)
            #expect(request.jsonBody.count == 2)
        }

        @Test("AUTH-02 successful login returns the session and stores the JWT")
        func loginStoresToken() async throws {
            MockURLProtocol.respond(status: 200, json: Fixtures.loginSuccess(role: "BUSINESS"))
            defer { MockURLProtocol.uninstall() }

            let response = try await api.login(email: TestAccounts.business, password: TestAccounts.password)

            #expect(response.user.role == .business)
            #expect(response.token == Fixtures.jwt)
            #expect(api.authToken == Fixtures.jwt)
        }

        @Test("AUTH-03 login maps each failure to its own error and stores no token (F-03)",
              arguments: [
                (400, Fixtures.loginMissingFields, APIErrorKind.badRequest, "Email and password are required"),
                (401, Fixtures.loginInvalid, APIErrorKind.unauthorized, "Invalid email or password"),
                (403, Fixtures.loginDeactivated, APIErrorKind.unauthorized, "Account is deactivated"),
                (500, Fixtures.internalServerError, APIErrorKind.serverError,
                 "The Kilala server had a problem. Please try again later.")
              ])
        func loginFailureMapsToMessage(status: Int, body: String, kind: APIErrorKind, message: String) async {
            MockURLProtocol.respond(status: status, json: body)
            defer { MockURLProtocol.uninstall() }

            await expectAPIError(kind, message: message) {
                _ = try await api.login(email: "missing@example.test", password: "wrong")
            }
            assertAnsweredByStub()
            #expect(api.authToken == nil)
        }

        @Test("AUTH-04 login throws when a 200 response does not match the contract")
        func loginMalformedBodyThrows() async {
            MockURLProtocol.respond(status: 200, json: #"{"message":"Login successful"}"#)
            defer { MockURLProtocol.uninstall() }

            await #expect(throws: DecodingError.self) {
                _ = try await api.login(email: TestAccounts.business, password: TestAccounts.password)
            }
            assertAnsweredByStub()
            #expect(api.authToken == nil)
        }

        // MARK: JWT on protected requests

        @Test("AUTH-05 profile request sends the JWT as a Bearer token")
        func profileRequestUsesBearerToken() async throws {
            MockURLProtocol.respond(status: 200, json: Fixtures.cardholderProfile)
            defer { MockURLProtocol.uninstall() }

            let profile = try await api.getCardholderProfile(token: Fixtures.jwt)

            let request = try #require(MockURLProtocol.lastRequest)
            #expect(request.httpMethod == "GET")
            #expect(request.url?.path() == "/api/cardholder/me")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer \(Fixtures.jwt)")
            #expect(profile.lguIdNumber == TestAccounts.juanCardNumber)
        }

        @Test("AUTH-06 profile request throws when the token is rejected",
              arguments: [401, 403])
        func profileRejectedTokenThrows(status: Int) async {
            MockURLProtocol.respond(status: status, json: #"{"error":"Invalid or expired token"}"#)
            defer { MockURLProtocol.uninstall() }

            let error = await #expect(throws: URLError.self) {
                _ = try await api.getCardholderProfile(token: "expired.token.value")
            }
            #expect(error?.code == .badServerResponse)
            assertAnsweredByStub()
        }

        // MARK: Cardholder signup – POST /api/auth/verify-record

        @Test("SIGN-01 verify-record sends the six agreed snake_case fields")
        func verifyRecordRequestShape() async throws {
            MockURLProtocol.respond(status: 200, json: Fixtures.verifyRecordSuccess)
            defer { MockURLProtocol.uninstall() }

            let result = try await api.verifyRecord(privilegeType: "PWD",
                                                    cardIdNumber: "MKT-PWD-2026-TEST-001",
                                                    firstName: "Ana", middleName: "Marie",
                                                    lastName: "Santos", dateOfBirth: "1999-03-17")

            let request = try #require(MockURLProtocol.lastRequest)
            #expect(request.httpMethod == "POST")
            #expect(request.url?.path() == "/api/auth/verify-record")
            let body = request.jsonBody
            #expect(Set(body.keys) == ["privilege_type", "card_id_number", "first_name",
                                       "middle_name", "last_name", "date_of_birth"])
            #expect(body["privilege_type"] as? String == "PWD")
            #expect(body["date_of_birth"] as? String == "1999-03-17")
            #expect(result.firstName == "Ana")
        }

        @Test("SIGN-02 verify-record maps 400/404 to badRequest with the backend message",
              arguments: [(400, #"{"error":"All fields are required for verification"}"#, "All fields are required for verification"),
                          (404, Fixtures.verifyRecordNotFound, "No matching LGU record found. Please check your details.")])
        func verifyRecordBadRequest(status: Int, json: String, message: String) async {
            MockURLProtocol.respond(status: status, json: json)
            defer { MockURLProtocol.uninstall() }

            await expectAPIError(.badRequest, message: message) {
                _ = try await api.verifyRecord(privilegeType: "PWD", cardIdNumber: "X", firstName: "A",
                                               middleName: "", lastName: "B", dateOfBirth: "2000-01-01")
            }
            assertAnsweredByStub()
        }

        @Test("SIGN-03 verify-record maps 403/409 to conflict with the backend message",
              arguments: [(403, Fixtures.verifyRecordInactive, "Cannot claim account. Card status is REVOKED."),
                          (409, Fixtures.verifyRecordClaimed, "This ID has already been claimed by an existing account.")])
        func verifyRecordConflict(status: Int, json: String, message: String) async {
            MockURLProtocol.respond(status: status, json: json)
            defer { MockURLProtocol.uninstall() }

            await expectAPIError(.conflict, message: message) {
                _ = try await api.verifyRecord(privilegeType: "PWD", cardIdNumber: "X", firstName: "A",
                                               middleName: "", lastName: "B", dateOfBirth: "2000-01-01")
            }
            assertAnsweredByStub()
        }

        // MARK: Business signup – GET /api/lgus, POST /api/auth/register-business

        @Test("SIGN-04 LGU list is fetched without authentication")
        func fetchLGUsIsPublic() async throws {
            MockURLProtocol.respond(status: 200, json: Fixtures.lguList)
            defer { MockURLProtocol.uninstall() }

            let lgus = try await api.fetchLGUs()

            let request = try #require(MockURLProtocol.lastRequest)
            #expect(request.url?.path() == "/api/lgus")
            #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
            #expect(lgus.map(\.lguCode) == ["MKT"])
        }

        @Test("SIGN-05 business registration posts the payload and stores the new JWT")
        func registerBusinessSuccess() async throws {
            MockURLProtocol.respond(status: 201, json: Fixtures.registerBusinessSuccess)
            defer { MockURLProtocol.uninstall() }

            let payload: [String: Any] = [
                "email": "qa.business@example.test", "password": "secret123",
                "lgu_id": TestAccounts.makatiLGUId, "business_name": "QA Pharmacy",
                "category": "PHARMACY", "business_permit_no": "QA-BP-0001",
                "tin_number": "000-000-000-000", "address": "1 Test Street, Makati City"
            ]
            let response = try await api.registerBusiness(payload: payload)

            let request = try #require(MockURLProtocol.lastRequest)
            #expect(request.httpMethod == "POST")
            #expect(request.url?.path() == "/api/auth/register-business")
            #expect(request.jsonBody["business_permit_no"] as? String == "QA-BP-0001")
            #expect(response.user.role == .business)
            #expect(api.authToken == Fixtures.jwt)
        }

        @Test("SIGN-06 business registration maps 400 to badRequest")
        func registerBusinessMissingFields() async {
            MockURLProtocol.respond(status: 400, json: Fixtures.registerBusinessMissingFields)
            defer { MockURLProtocol.uninstall() }

            await expectAPIError(.badRequest, message: "Missing required business registration fields") {
                _ = try await api.registerBusiness(payload: [:])
            }
            assertAnsweredByStub()
            #expect(api.authToken == nil)
        }

        @Test("SIGN-07 business registration maps 409 to conflict")
        func registerBusinessDuplicate() async {
            MockURLProtocol.respond(status: 409, json: Fixtures.registerBusinessDuplicate)
            defer { MockURLProtocol.uninstall() }

            await expectAPIError(.conflict, message: "Email or Business Permit No. already exists") {
                _ = try await api.registerBusiness(payload: ["email": "dup@example.test"])
            }
            assertAnsweredByStub()
        }

        @Test("SIGN-08 business registration maps 5xx to serverError")
        func registerBusinessServerError() async {
            MockURLProtocol.respond(status: 500, json: Fixtures.internalServerError)
            defer { MockURLProtocol.uninstall() }

            await expectAPIError(.serverError, message: "Internal server error") {
                _ = try await api.registerBusiness(payload: ["email": "x@example.test"])
            }
            assertAnsweredByStub()
        }

        // MARK: Cardholder signup – POST /api/auth/claim-cardholder (F-01)

        @Test("SIGN-09 claim-cardholder sends the four agreed snake_case fields")
        func claimCardholderRequestShape() async throws {
            MockURLProtocol.respond(status: 201, json: Fixtures.loginSuccess(role: "CARDHOLDER"))
            defer { MockURLProtocol.uninstall() }

            _ = try await api.claimCardholder(lguIdNumber: "MKT-PWD-2026-TEST-001", dateOfBirth: "1999-03-17",
                                              email: "qa.ios.claim@example.test", password: "QaPassword123!")

            let request = try #require(MockURLProtocol.lastRequest)
            #expect(request.httpMethod == "POST")
            #expect(request.url?.path() == "/api/auth/claim-cardholder")
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
            #expect(request.jsonBody["lgu_id_number"] as? String == "MKT-PWD-2026-TEST-001")
            #expect(request.jsonBody["date_of_birth"] as? String == "1999-03-17")
            #expect(request.jsonBody["email"] as? String == "qa.ios.claim@example.test")
            #expect(request.jsonBody["password"] as? String == "QaPassword123!")
            #expect(request.jsonBody.count == 4)
        }

        @Test("SIGN-10 claim-cardholder success returns a cardholder session and stores the JWT")
        func claimCardholderSignsIn() async throws {
            MockURLProtocol.respond(status: 201, json: Fixtures.loginSuccess(role: "CARDHOLDER"))
            defer { MockURLProtocol.uninstall() }

            let session = try await api.claimCardholder(lguIdNumber: "MKT-PWD-2026-TEST-001", dateOfBirth: "1999-03-17",
                                                        email: "qa.ios.claim@example.test", password: "QaPassword123!")

            #expect(session.user.role == .cardholder)
            #expect(session.token == Fixtures.jwt)
            #expect(api.authToken == Fixtures.jwt)
        }

        @Test("SIGN-11 claim-cardholder maps 409 to conflict (ID already claimed or email in use)",
              arguments: [Fixtures.claimAlreadyClaimed, Fixtures.claimEmailInUse])
        func claimCardholderConflict(body: String) async throws {
            MockURLProtocol.respond(status: 409, json: body)
            defer { MockURLProtocol.uninstall() }
            let expected = try #require(Fixtures.errorMessage(in: body))

            await expectAPIError(.conflict, message: expected) {
                _ = try await api.claimCardholder(lguIdNumber: "MKT-PWD-2026-00481", dateOfBirth: "1990-05-15",
                                                  email: "qa.ios.claim@example.test", password: "QaPassword123!")
            }
            assertAnsweredByStub()
            #expect(api.authToken == nil)
        }

        @Test("SIGN-12 claim-cardholder maps 400/404 to badRequest and 5xx to serverError",
              arguments: [(400, Fixtures.claimMissingFields, APIErrorKind.badRequest),
                          (404, Fixtures.claimNotFound, APIErrorKind.badRequest),
                          (500, Fixtures.internalServerError, APIErrorKind.serverError)])
        func claimCardholderErrors(status: Int, body: String, kind: APIErrorKind) async throws {
            MockURLProtocol.respond(status: status, json: body)
            defer { MockURLProtocol.uninstall() }
            let expected = try #require(Fixtures.errorMessage(in: body))

            await expectAPIError(kind, message: expected) {
                _ = try await api.claimCardholder(lguIdNumber: "MKT-PWD-0000-NONE", dateOfBirth: "2000-01-01",
                                                  email: "qa.ios.claim@example.test", password: "QaPassword123!")
            }
            assertAnsweredByStub()
            #expect(api.authToken == nil)
        }
    }
}

// MARK: - Helpers

/// Fails unless exactly one request was answered by MockURLProtocol. Without this check,
/// an error-path test could pass by accident against a running real backend if the stub
/// ever stopped intercepting, because the real backend returns the same errors.
func assertAnsweredByStub(sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(MockURLProtocol.requests.count == 1,
            "Request was not answered by MockURLProtocol", sourceLocation: sourceLocation)
}

enum APIErrorKind { case conflict, badRequest, unauthorized, serverError }

/// Asserts that `body` throws the given APIError case carrying `message`.
@MainActor
func expectAPIError(
    _ kind: APIErrorKind,
    message: String,
    sourceLocation: SourceLocation = #_sourceLocation,
    _ body: () async throws -> Void
) async {
    do {
        try await body()
        Issue.record("Expected APIError.\(kind) but no error was thrown", sourceLocation: sourceLocation)
    } catch let error as APIError {
        switch (kind, error) {
        case (.conflict, .conflict(let actual)),
             (.badRequest, .badRequest(let actual)),
             (.unauthorized, .unauthorized(let actual)),
             (.serverError, .serverError(let actual)):
            #expect(actual == message, sourceLocation: sourceLocation)
        default:
            Issue.record("Expected APIError.\(kind) but got \(error)", sourceLocation: sourceLocation)
        }
    } catch {
        Issue.record("Expected APIError.\(kind) but got \(type(of: error)): \(error)", sourceLocation: sourceLocation)
    }
}
