//
//  User.swift
//  
//
//  Created by Joshua Calibo on 10/21/26.
//

import Foundation

// Matches the user_role ENUM in PostgreSQL database
enum UserRole: String, Codable {
    case cardholder = "CARDHOLDER"
    case business = "BUSINESS"
    case lguAdmin = "LGU_ADMIN"
}

// Matches the user object returned from POST /api/auth/login endpoint
struct User: Identifiable, Codable {
    let id: UUID
    let email: String
    let role: UserRole
}
