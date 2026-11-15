//
//  ModelContractTests.swift
//  KilalaTests
//
//  Created by Edson John Willie on 11/6/26.
//
//  Sprint 1 – "Finalize API agreements" (iOS side).
//  Verifies the app's Codable models decode the JSON the backend agreed to send.
//  Runs offline; no backend needed.
//

import Foundation
import Testing
@testable import Kilala

@MainActor
@Suite("S1-API · Model contracts")
struct ModelContractTests {

    private var snakeCaseDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    // MARK: Login (POST /api/auth/login) – decoded with a plain JSONDecoder in APIService.login

    @Test("API-01 Login response decodes token and user for every role",
          arguments: ["CARDHOLDER", "BUSINESS", "LGU_ADMIN"])
    func loginResponseDecodes(role: String) throws {
        let response = try JSONDecoder().decode(LoginResponse.self, from: Data(json: Fixtures.loginSuccess(role: role)))

        #expect(response.message == "Login successful")
        #expect(response.token == Fixtures.jwt)
        #expect(response.user.id.uuidString.lowercased() == "22222222-2222-2222-2222-222222222222")
        #expect(response.user.role.rawValue == role)
    }

    @Test("API-02 UserRole raw values match the agreed role strings")
    func userRoleRawValues() {
        #expect(UserRole.cardholder.rawValue == "CARDHOLDER")
        #expect(UserRole.business.rawValue == "BUSINESS")
        #expect(UserRole.lguAdmin.rawValue == "LGU_ADMIN")
    }

    @Test("API-03 Login response with an unknown role is rejected")
    func unknownRoleIsRejected() {
        let json = Fixtures.loginSuccess(role: "SUPER_ADMIN")
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(LoginResponse.self, from: Data(json: json))
        }
    }

    @Test("API-04 Login response without a token is rejected")
    func missingTokenIsRejected() {
        let json = #"{"message":"Login successful","user":{"id":"22222222-2222-2222-2222-222222222222","email":"a@b.c","role":"BUSINESS"}}"#
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(LoginResponse.self, from: Data(json: json))
        }
    }

    @Test("API-05 User id must be a UUID")
    func nonUUIDUserIdIsRejected() {
        let json = #"{"message":"ok","token":"t","user":{"id":"42","email":"a@b.c","role":"BUSINESS"}}"#
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(LoginResponse.self, from: Data(json: json))
        }
    }

    // MARK: Signup contracts

    @Test("API-06 LGU list decodes, including a NULL province")
    func lguListDecodes() throws {
        let lgus = try snakeCaseDecoder.decode([LGU].self, from: Data(json: Fixtures.lguList))

        #expect(lgus.count == 1)
        #expect(lgus.first?.lguCode == "MKT")
        #expect(lgus.first?.municipalityName == "Makati City")
        #expect(lgus.first?.province == nil)
        #expect(lgus.first?.region == "NCR")
    }

    @Test("API-07 Verify-record response decodes when middle_name is absent")
    func verifyRecordDecodesWithoutMiddleName() throws {
        let response = try snakeCaseDecoder.decode(SignupVerificationResponse.self,
                                                   from: Data(json: Fixtures.verifyRecordSuccess))

        #expect(response.message == "Record verified successfully")
        #expect(response.profileId.uuidString.lowercased() == "44444444-4444-4444-4444-444444444443")
        #expect(response.firstName == "Ana")
        #expect(response.middleName == nil)
        #expect(response.lastName == "Santos")
    }

    @Test("API-08 Business registration response decodes user, token and profile")
    func businessRegistrationDecodes() throws {
        let response = try snakeCaseDecoder.decode(BusinessRegistrationResponse.self,
                                                   from: Data(json: Fixtures.registerBusinessSuccess))

        #expect(response.message == "Business registered successfully")
        #expect(response.token == Fixtures.jwt)
        #expect(response.user.role == .business)
        #expect(response.businessProfile.businessName == "QA Pharmacy")
        #expect(response.businessProfile.branchName == nil)
        #expect(response.businessProfile.category == "PHARMACY")
        #expect(response.businessProfile.businessPermitNo == "QA-BP-0001")
        #expect(response.businessProfile.isAccredited)
        #expect(response.businessProfile.userId == response.user.id)
    }

    // MARK: Post-login contract used right after authentication

    @Test("API-09 Cardholder profile decodes and ignores extra columns")
    func cardholderProfileDecodes() throws {
        let profile = try snakeCaseDecoder.decode(CardholderProfile.self,
                                                  from: Data(json: Fixtures.cardholderProfile))

        #expect(profile.lguIdNumber == TestAccounts.juanCardNumber)
        #expect(profile.privilegeType == "PWD")
        #expect(profile.status == "ACTIVE")
        #expect(profile.lguName == "Makati City")
        #expect(profile.fullName == "Juan Santos Dela Cruz")
    }

    @Test("API-10 Cardholder full name skips a missing or blank middle name",
          arguments: [nil, "", "Clara"])
    func fullNameHandlesMiddleName(middleName: String?) throws {
        var object = try #require(
            try JSONSerialization.jsonObject(with: Data(json: Fixtures.cardholderProfile)) as? [String: Any]
        )
        object["first_name"] = "Maria"
        object["last_name"] = "Bautista"
        object["middle_name"] = middleName ?? NSNull()
        let data = try JSONSerialization.data(withJSONObject: object)

        let profile = try snakeCaseDecoder.decode(CardholderProfile.self, from: data)

        let expected = (middleName ?? "").isEmpty ? "Maria Bautista" : "Maria \(middleName!) Bautista"
        #expect(profile.fullName == expected)
    }
}
