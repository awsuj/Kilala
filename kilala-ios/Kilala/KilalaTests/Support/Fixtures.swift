//
//  Fixtures.swift
//  KilalaTests
//
//  Created by Edson John Willie on 11/6/26.
//
//  Sprint 1 QA – shared test data.
//
//  The JSON payloads below mirror what the Express backend
//  (backend/src/index.ts) actually returns, so the decoding tests double as
//  the iOS side of the "Finalize API agreements" contract. If a test here
//  starts failing after a backend change, the API agreement has changed.
//

import Foundation

/// Seeded accounts from backend/src/schema/seed.sql (documented in the team masterfile).
/// These are local test credentials only – never real cardholder data.
enum TestAccounts {
    static let password = "MockHashForTestingOnly123456789012"

    static let cardholderPWD = "juan.pwd@email.com"
    static let cardholderSenior = "maria.senior@email.com"
    static let business = "cashier@mercury-mkt.com"
    static let lguAdmin = "admin@makati.gov.ph"

    static let juanCardNumber = "MKT-PWD-2026-00481"
    static let makatiLGUId = "11111111-1111-1111-1111-111111111111"
}

enum Fixtures {

    static let jwt = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjEifQ.c2lnbmF0dXJl"

    /// POST /api/auth/login → 200
    static func loginSuccess(role: String) -> String {
        """
        {
          "message": "Login successful",
          "token": "\(jwt)",
          "user": {
            "id": "22222222-2222-2222-2222-222222222222",
            "email": "user@example.test",
            "role": "\(role)"
          }
        }
        """
    }

    /// POST /api/auth/login → 401
    static let loginInvalid = #"{"error":"Invalid email or password"}"#
    static let loginMissingFields = #"{"error":"Email and password are required"}"#
    static let loginDeactivated = #"{"error":"Account is deactivated"}"#

    /// GET /api/lgus → 200 (province is NULL for NCR cities)
    static let lguList = """
    [
      {
        "id": "11111111-1111-1111-1111-111111111111",
        "lgu_code": "MKT",
        "municipality_name": "Makati City",
        "province": null,
        "region": "NCR"
      }
    ]
    """

    /// POST /api/auth/verify-record → 200.
    /// Note: the backend SELECT does not include middle_name, so the key is absent.
    static let verifyRecordSuccess = """
    {
      "message": "Record verified successfully",
      "profile_id": "44444444-4444-4444-4444-444444444443",
      "first_name": "Ana",
      "last_name": "Santos"
    }
    """

    static let verifyRecordNotFound = #"{"error":"No matching LGU record found. Please check your details."}"#
    static let verifyRecordClaimed = #"{"error":"This ID has already been claimed by an existing account."}"#
    static let verifyRecordInactive = #"{"error":"Cannot claim account. Card status is REVOKED."}"#

    /// POST /api/auth/register-business → 201.
    /// Top-level "businessProfile" is camelCase; its fields are raw snake_case DB columns.
    static let registerBusinessSuccess = """
    {
      "message": "Business registered successfully",
      "token": "\(jwt)",
      "user": {
        "id": "22222222-2222-2222-2222-222222222299",
        "email": "qa.business@example.test",
        "role": "BUSINESS"
      },
      "businessProfile": {
        "id": "55555555-5555-5555-5555-555555555599",
        "user_id": "22222222-2222-2222-2222-222222222299",
        "lgu_id": "11111111-1111-1111-1111-111111111111",
        "business_name": "QA Pharmacy",
        "branch_name": null,
        "category": "PHARMACY",
        "business_permit_no": "QA-BP-0001",
        "tin_number": "000-000-000-000",
        "address": "1 Test Street, Makati City",
        "is_accredited": true,
        "created_at": "2026-11-06T03:00:00.000Z",
        "updated_at": "2026-11-06T03:00:00.000Z"
      }
    }
    """

    static let registerBusinessMissingFields = #"{"error":"Missing required business registration fields"}"#
    static let registerBusinessDuplicate = #"{"error":"Email or Business Permit No. already exists"}"#
    static let internalServerError = #"{"error":"Internal server error"}"#

    // POST /api/auth/claim-cardholder (success returns the same shape as loginSuccess)
    static let claimMissingFields = #"{"error":"All fields are required to claim your ID"}"#
    static let claimNotFound = #"{"error":"No matching LGU record found"}"#
    static let claimAlreadyClaimed = #"{"error":"This ID has already been claimed by an account"}"#
    static let claimEmailInUse = #"{"error":"Email is already in use"}"#

    /// The `error` text of a backend error body, for tests that expect it verbatim.
    static func errorMessage(in json: String) -> String? {
        let object = try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any]
        return object?["error"] as? String
    }

    /// GET /api/cardholder/me → 200 (subset of columns the app decodes, plus extras it must ignore).
    static let cardholderProfile = """
    {
      "id": "44444444-4444-4444-4444-444444444441",
      "user_id": "22222222-2222-2222-2222-222222222222",
      "lgu_id": "11111111-1111-1111-1111-111111111111",
      "lgu_id_number": "MKT-PWD-2026-00481",
      "first_name": "Juan",
      "middle_name": "Santos",
      "last_name": "Dela Cruz",
      "date_of_birth": "1998-05-14T00:00:00.000Z",
      "sex": "Male",
      "address": "123 Ayala Ave, Makati City",
      "privilege_type": "PWD",
      "disability_type": "Visual Impairment",
      "status": "ACTIVE",
      "qr_secret_token": "KILALA-QR-MKT-PWD-00481-SECRET",
      "expiry_date": "2029-11-06T00:00:00.000Z",
      "lgu_name": "Makati City",
      "lgu_code": "MKT"
    }
    """
}

extension Data {
    init(json: String) { self.init(json.utf8) }
}
