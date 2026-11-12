//
//  InputValidationTests.swift
//  KilalaTests
//
//  Created by Edson John Willie on 11/13/26.
//
//  Sprint 1 fix F-06 – client-side email and password checks used by the
//  cardholder (create login) and business sign-up forms. Runs offline.
//

import Testing
@testable import Kilala

@MainActor
@Suite("S1-VAL · Sign-up input validation")
struct InputValidationTests {

    @Test("VAL-01 Well-formed email addresses are accepted",
          arguments: ["juan.pwd@email.com", "cashier@mercury-mkt.com", "qa.ios.1a2b@example.test",
                      "first.last+tag@sub.domain.ph", "  padded@example.com  "])
    func validEmails(email: String) {
        #expect(InputValidation.isValidEmail(email))
    }

    @Test("VAL-02 Malformed email addresses are rejected",
          arguments: ["", "juan", "juan@", "@email.com", "juan@email", "juan @email.com",
                      "juan@@email.com", "juan@email.c"])
    func invalidEmails(email: String) {
        #expect(!InputValidation.isValidEmail(email))
    }

    @Test("VAL-03 Passwords need at least 8 characters",
          arguments: [("", false), ("1234567", false), ("12345678", true), ("QaPassword123!", true)])
    func passwordLength(password: String, isAcceptable: Bool) {
        let problem = InputValidation.passwordProblem(password)
        #expect((problem == nil) == isAcceptable)
        if !isAcceptable {
            #expect(problem == "Password must be at least 8 characters.")
        }
    }
}
