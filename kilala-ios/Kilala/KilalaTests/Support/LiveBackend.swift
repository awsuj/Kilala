//
//  LiveBackend.swift
//  KilalaTests
//
//  Created by Edson John Willie on 11/6/26.
//
//  Sprint 1 QA – helpers for tests that call the real backend on localhost:5001.
//
//  Live tests are skipped automatically when the backend is not running, so the
//  suite still passes (with skips) on a machine without the backend.
//
//  Tests that CREATE data (e.g. registering a new business) only run when the
//  environment variable KILALA_ALLOW_WRITE_TESTS=1 is set, because the backend
//  may be pointed at the shared team database. See kilala-ios/TESTING.md.
//

import Foundation

enum LiveBackend {

    /// Must match `APIService.baseURL` (the app hard-codes localhost:5001).
    static let baseURL = URL(string: "http://localhost:5001/api")!

    /// Uses its own ephemeral session so MockURLProtocol can never intercept it.
    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 5
        config.protocolClasses = []
        return URLSession(configuration: config)
    }()

    static var writeTestsEnabled: Bool {
        ProcessInfo.processInfo.environment["KILALA_ALLOW_WRITE_TESTS"] == "1"
    }

    /// True when GET /api/health answers {"status":"healthy"}.
    static func isReachable() async -> Bool {
        guard let response = try? await send("GET", "/health") else { return false }
        return response.status == 200 && response.json["status"] as? String == "healthy"
    }

    /// True when the unclaimed PWD record added by the backend QA seed (PR #32) is present.
    static func hasUnclaimedSeedRecord() async -> Bool {
        guard await isReachable(),
              let response = try? await send("POST", "/auth/verify-record", body: UnclaimedRecord.body)
        else { return false }
        return response.status == 200
    }

    struct Response {
        let status: Int
        let data: Data
        var json: [String: Any] {
            (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        }
        var error: String? { json["error"] as? String }
    }

    @discardableResult
    static func send(
        _ method: String,
        _ path: String,
        body: [String: Any]? = nil,
        bearer token: String? = nil,
        rawAuthorization: String? = nil
    ) async throws -> Response {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = method
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let rawAuthorization {
            request.setValue(rawAuthorization, forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await session.data(for: request)
        return Response(status: (response as? HTTPURLResponse)?.statusCode ?? -1, data: data)
    }

    /// Logs in through the raw API and returns the JWT.
    static func token(for email: String) async throws -> String {
        let response = try await send("POST", "/auth/login",
                                      body: ["email": email, "password": TestAccounts.password])
        guard let token = response.json["token"] as? String else {
            throw URLError(.userAuthenticationRequired)
        }
        return token
    }

    /// Seed record from PR #32 (backend QA). Only present once that seed is applied.
    enum UnclaimedRecord {
        static let profileId = "44444444-4444-4444-4444-444444444443"
        static let body: [String: Any] = [
            "privilege_type": "PWD",
            "card_id_number": "MKT-PWD-2026-TEST-001",
            "first_name": "Ana",
            "middle_name": "Marie",
            "last_name": "Santos",
            "date_of_birth": "1999-03-17"
        ]
    }
}

/// Decodes the claims segment of a JWT without verifying the signature.
enum JWT {
    static func claims(of token: String) -> [String: Any]? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }
        var base64 = parts[1]
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        guard let data = Data(base64Encoded: base64) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}
