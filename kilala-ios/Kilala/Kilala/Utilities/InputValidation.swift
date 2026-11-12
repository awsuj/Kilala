//
//  InputValidation.swift
//  Kilala
//
//  Created by Edson John Willie on 11/13/26.
//

import Foundation

/// Client-side checks shared by the cardholder and business sign-up forms.
/// The backend stays the source of truth; these only catch obvious mistakes early.
enum InputValidation {
    static let minimumPasswordLength = 8

    static let invalidEmailMessage = "Enter a valid email address, like name@example.com."
    static let shortPasswordMessage = "Password must be at least \(minimumPasswordLength) characters."

    /// A practical format check (something@domain.tld), not full RFC 5322 validation.
    static func isValidEmail(_ email: String) -> Bool {
        let pattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}$"#
        return email.trimmingCharacters(in: .whitespacesAndNewlines)
            .range(of: pattern, options: .regularExpression) != nil
    }

    /// Returns a message describing what is wrong with the password, or nil if it is acceptable.
    static func passwordProblem(_ password: String) -> String? {
        password.count < minimumPasswordLength ? shortPasswordMessage : nil
    }
}
