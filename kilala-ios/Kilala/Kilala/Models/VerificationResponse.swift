//
//  VerificationResponse.swift
//  Kilala
//
//  Created by Joshua Calibo on 10/22/26.
//

import Foundation

struct VerificationResponse: Codable, Identifiable {
    var id: String {
        logId ?? scanTimestamp
    }
    
    let logId: String?
    let isValid: Bool
    let scanTimestamp: String
    let message: String
    let cardholderSummary: CardholderSummary?
}

struct CardholderSummary: Codable, Identifiable {
    let id: UUID
    let fullName: String
    let dateOfBirth: String
    let sex: String
    let privilegeType: String
    let disabilityType: String?
    let lguIdNumber: String
    let lguName: String
    let status: String
    let expiryDate: String?
    let photoUrl: String?
}
