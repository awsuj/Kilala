//
//  LiveBackendContractTests.swift
//  KilalaTests
//
//  Created by Edson John Willie on 11/6/26.
//
//  Sprint 1 – "PostgreSQL deployment", "JWT Auth API" and "Finalize API agreements",
//  checked end to end: the real APIService talking to the real backend on
//  localhost:5001, backed by a database loaded with schema.sql + seed.sql.
//
//  Skipped automatically when the backend is not running.
//  Read-only by default (login only updates users.last_login_at and, through the
//  trg_users_updated_at trigger, users.updated_at). The test that
//  registers a new business needs KILALA_ALLOW_WRITE_TESTS=1.
//

import Foundation
import Testing
@testable import Kilala

extension NetworkTests {

    @MainActor
    @Suite("S1-LIVE · Real backend on localhost:5001",
           .serialized,
           .enabled("Backend not reachable on localhost:5001 – start it with `npm run dev` in backend/") {
               await LiveBackend.isReachable()
           })
    struct LiveBackendContractTests {

        private let api = APIService.shared

        init() {
            APIService.shared.authToken = nil
        }

        // MARK: PostgreSQL deployment / connectivity

        @Test("DB-01 Health endpoint reports the API as healthy")
        func healthIsHealthy() async throws {
            let response = try await LiveBackend.send("GET", "/health")
            #expect(response.status == 200)
            #expect(response.json["status"] as? String == "healthy")
            #expect(response.json["system"] as? String == "Kilala Backend API")
        }

        @Test("DB-02 LGU list comes from the database and contains the seeded Makati LGU")
        func lguListComesFromDatabase() async throws {
            let lgus = try await api.fetchLGUs()
            let makati = try #require(lgus.first { $0.lguCode == "MKT" })
            #expect(makati.municipalityName == "Makati City")
            #expect(makati.id.uuidString.lowercased() == TestAccounts.makatiLGUId)
        }

        // MARK: Login through the app's own client

        @Test("LIVE-01 Seeded accounts log in through APIService with the right role",
              arguments: [(TestAccounts.cardholderPWD, "CARDHOLDER"),
                          (TestAccounts.cardholderSenior, "CARDHOLDER"),
                          (TestAccounts.business, "BUSINESS"),
                          (TestAccounts.lguAdmin, "LGU_ADMIN")])
        func seededAccountsLogIn(email: String, role: String) async throws {
            let response = try await api.login(email: email, password: TestAccounts.password)
            #expect(response.message == "Login successful")
            #expect(response.user.email == email)
            #expect(response.user.role.rawValue == role)
            #expect(api.authToken == response.token)
        }

        @Test("LIVE-02 Wrong password is rejected by APIService with the backend's message")
        func wrongPasswordRejected() async {
            await expectAPIError(.unauthorized, message: "Invalid email or password") {
                _ = try await api.login(email: TestAccounts.cardholderPWD, password: "not-the-password")
            }
            #expect(api.authToken == nil)
        }

        @Test("LIVE-03 Login error contract: missing fields → 400, bad credentials → 401",
              arguments: [([String: String](), 400, "Email and password are required"),
                          (["email": TestAccounts.cardholderPWD], 400, "Email and password are required"),
                          (["email": "missing@example.test", "password": "x"], 401, "Invalid email or password")])
        func loginErrorContract(body: [String: String], status: Int, message: String) async throws {
            let response = try await LiveBackend.send("POST", "/auth/login", body: body)
            #expect(response.status == status)
            #expect(response.error == message)
        }

        // MARK: JWT Auth API

        @Test("JWT-01 Issued token is a 3-part JWT whose claims match the user and expire in 24 h")
        func jwtClaims() async throws {
            let response = try await api.login(email: TestAccounts.business, password: TestAccounts.password)
            #expect(response.token.split(separator: ".").count == 3)

            let claims = try #require(JWT.claims(of: response.token))
            #expect((claims["id"] as? String)?.lowercased() == response.user.id.uuidString.lowercased())
            #expect(claims["email"] as? String == TestAccounts.business)
            #expect(claims["role"] as? String == "BUSINESS")

            let issuedAt = try #require(claims["iat"] as? Double)
            let expiresAt = try #require(claims["exp"] as? Double)
            #expect(expiresAt - issuedAt == 24 * 60 * 60)
            #expect(expiresAt > Date().timeIntervalSince1970)
        }

        @Test("JWT-02 Cardholder token opens the cardholder profile through APIService")
        func cardholderTokenOpensProfile() async throws {
            let session = try await api.login(email: TestAccounts.cardholderPWD, password: TestAccounts.password)
            let profile = try await api.getCardholderProfile(token: session.token)
            #expect(profile.lguIdNumber == TestAccounts.juanCardNumber)
            #expect(profile.fullName == "Juan Santos Dela Cruz")
        }

        @Test("JWT-03 Protected route rejects missing, malformed and forged tokens",
              arguments: [(nil as String?, 401, "Access token required"),
                          ("Bearer", 401, "Access token required"),
                          ("Bearer not-a-jwt", 403, "Invalid or expired token"),
                          ("Bearer \(Fixtures.jwt)", 403, "Invalid or expired token")])
        func protectedRouteRejectsBadTokens(header: String?, status: Int, message: String) async throws {
            let response = try await LiveBackend.send("GET", "/cardholder/me", rawAuthorization: header)
            #expect(response.status == status)
            #expect(response.error == message)
        }

        @Test("JWT-04 Valid token with the wrong role is forbidden",
              arguments: [(TestAccounts.business, "/cardholder/me"),
                          (TestAccounts.lguAdmin, "/cardholder/me"),
                          (TestAccounts.cardholderPWD, "/business/me"),
                          (TestAccounts.cardholderPWD, "/lgu/dashboard")])
        func wrongRoleIsForbidden(email: String, path: String) async throws {
            let token = try await LiveBackend.token(for: email)
            let response = try await LiveBackend.send("GET", path, bearer: token)
            #expect(response.status == 403)
            #expect(response.error == "Forbidden: Insufficient permissions")
        }

        @Test("JWT-05 APIService surfaces a rejected token as an error")
        func apiServiceRejectsForgedToken() async {
            await #expect(throws: URLError.self) {
                _ = try await api.getCardholderProfile(token: Fixtures.jwt)
            }
        }

        // MARK: Signup contracts (read-only)

        @Test("LIVE-04 Verify-record rejects missing fields with 400")
        func verifyRecordMissingFields() async throws {
            let response = try await LiveBackend.send("POST", "/auth/verify-record", body: [:])
            #expect(response.status == 400)
            #expect(response.error == "All fields are required for verification")
        }

        @Test("LIVE-05 Verify-record with unknown details surfaces as badRequest")
        func verifyRecordNotFound() async {
            await expectAPIError(.badRequest, message: "No matching LGU record found. Please check your details.") {
                _ = try await api.verifyRecord(privilegeType: "PWD", cardIdNumber: "MKT-PWD-0000-NOPE",
                                               firstName: "Nobody", middleName: "", lastName: "Here",
                                               dateOfBirth: "2000-01-01")
            }
        }

        @Test("LIVE-06 Verify-record for an already-claimed card surfaces as conflict")
        func verifyRecordAlreadyClaimed() async {
            await expectAPIError(.conflict, message: "This ID has already been claimed by an existing account.") {
                _ = try await api.verifyRecord(privilegeType: "PWD", cardIdNumber: TestAccounts.juanCardNumber,
                                               firstName: "Juan", middleName: "Santos", lastName: "Dela Cruz",
                                               dateOfBirth: "1998-05-14")
            }
        }

        @Test("LIVE-07 Verify-record for the unclaimed seed record succeeds",
              .enabled("Unclaimed seed record (PR #32) not present in this database") {
                  await LiveBackend.hasUnclaimedSeedRecord()
              })
        func verifyRecordUnclaimed() async throws {
            let body = LiveBackend.UnclaimedRecord.body
            let result = try await api.verifyRecord(privilegeType: "PWD",
                                                    cardIdNumber: body["card_id_number"] as! String,
                                                    firstName: "Ana", middleName: "Marie", lastName: "Santos",
                                                    dateOfBirth: "1999-03-17")
            #expect(result.profileId.uuidString.lowercased() == LiveBackend.UnclaimedRecord.profileId)
            #expect(result.firstName == "Ana")
        }

        @Test("LIVE-08 Business registration with missing fields surfaces as badRequest")
        func registerBusinessMissingFields() async {
            await expectAPIError(.badRequest, message: "Missing required business registration fields") {
                _ = try await api.registerBusiness(payload: ["email": "incomplete@example.test"])
            }
            #expect(api.authToken == nil)
        }

        // MARK: Signup contracts (creates data – opt-in)

        @Test("LIVE-09 New business registers, receives a BUSINESS JWT, and a duplicate is refused",
              .enabled(if: LiveBackend.writeTestsEnabled, "Set KILALA_ALLOW_WRITE_TESTS=1 to run tests that create data"))
        func registerBusinessThenDuplicate() async throws {
            let suffix = UUID().uuidString.prefix(8).lowercased()
            let payload: [String: Any] = [
                "email": "qa.ios.\(suffix)@example.test",
                "password": "QaPassword123!",
                "lgu_id": TestAccounts.makatiLGUId,
                "business_name": "QA iOS Store \(suffix)",
                "category": "GROCERY",
                "business_permit_no": "QA-IOS-\(suffix)",
                "tin_number": "000-000-000-000",
                "address": "1 QA Street, Makati City"
            ]

            let response = try await api.registerBusiness(payload: payload)
            #expect(response.user.role == .business)
            #expect(response.businessProfile.businessPermitNo == "QA-IOS-\(suffix)")
            #expect(response.businessProfile.category == "GROCERY")
            #expect(JWT.claims(of: response.token)?["role"] as? String == "BUSINESS")

            // The new account can log in immediately.
            let login = try await api.login(email: "qa.ios.\(suffix)@example.test", password: "QaPassword123!")
            #expect(login.user.id == response.user.id)

            // Registering the same email/permit again is refused.
            await expectAPIError(.conflict, message: "Email or Business Permit No. already exists") {
                _ = try await api.registerBusiness(payload: payload)
            }
        }
    }
}
