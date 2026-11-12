//
//  SchemaContractTests.swift
//  KilalaTests
//
//  Created by Edson John Willie on 11/6/26.
//
//  Sprint 1 – "Database Schema" (iOS side).
//  Reads backend/src/schema/schema.sql from the repository and checks that the
//  enum values the iOS app sends or decodes still exist in the database schema.
//  Runs offline. Skipped if the schema file cannot be found (e.g. the iOS
//  project was copied out of the monorepo).
//

import Foundation
import Testing
@testable import Kilala

enum SchemaFile {
    /// <repo>/kilala-ios/Kilala/KilalaTests/SchemaContractTests.swift → <repo>/backend/src/schema/schema.sql
    static let url: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // KilalaTests
        .deletingLastPathComponent()   // Kilala (project folder)
        .deletingLastPathComponent()   // kilala-ios
        .deletingLastPathComponent()   // repo root
        .appending(path: "backend/src/schema/schema.sql")

    static var exists: Bool { FileManager.default.fileExists(atPath: url.path) }

    /// Values of `CREATE TYPE <name> AS ENUM (...)`.
    static func enumValues(_ typeName: String) throws -> Set<String> {
        let sql = try String(contentsOf: url, encoding: .utf8)
        let pattern = "CREATE TYPE \(typeName) AS ENUM \\(([^)]*)\\)"
        let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        let range = NSRange(sql.startIndex..., in: sql)
        guard let match = regex.firstMatch(in: sql, range: range),
              let body = Range(match.range(at: 1), in: sql) else { return [] }
        let valueRegex = try NSRegularExpression(pattern: "'([^']+)'")
        let bodyText = String(sql[body])
        let matches = valueRegex.matches(in: bodyText, range: NSRange(bodyText.startIndex..., in: bodyText))
        return Set(matches.compactMap { Range($0.range(at: 1), in: bodyText).map { String(bodyText[$0]) } })
    }
}

@MainActor
@Suite("S1-SCH · Database schema contracts", .enabled(if: SchemaFile.exists, "backend/src/schema/schema.sql not found"))
struct SchemaContractTests {

    @Test("SCH-01 iOS UserRole matches the user_role enum exactly")
    func userRoleMatchesSchema() throws {
        let schemaRoles = try SchemaFile.enumValues("user_role")
        let appRoles: Set<String> = [UserRole.cardholder.rawValue,
                                     UserRole.business.rawValue,
                                     UserRole.lguAdmin.rawValue]
        #expect(!schemaRoles.isEmpty)
        #expect(appRoles == schemaRoles)
    }

    @Test("SCH-02 Cardholder signup privilege types exist in the privilege_type enum")
    func privilegeTypesMatchSchema() throws {
        let schemaTypes = try SchemaFile.enumValues("privilege_type")
        let appTypes: Set<String> = [CardholderSignupView.PrivilegeType.pwd.rawValue,
                                     CardholderSignupView.PrivilegeType.seniorCitizen.rawValue]
        #expect(appTypes == schemaTypes)
    }

    @Test("SCH-03 business_category enum matches the sign-up category list")
    func businessCategoriesMatchSchema() throws {
        // Reads the list the business sign-up screen actually shows (F-05).
        let appCategories = Set(BusinessSignupView.categories)
        #expect(appCategories.count == BusinessSignupView.categories.count, "Duplicate category in the app list")
        #expect(try SchemaFile.enumValues("business_category") == appCategories)
    }

    @Test("SCH-04 card_status enum contains the four agreed statuses")
    func cardStatusesExist() throws {
        let statuses = try SchemaFile.enumValues("card_status")
        #expect(statuses.isSuperset(of: ["ACTIVE", "EXPIRED", "REVOKED", "SUSPENDED"]))
    }
}
