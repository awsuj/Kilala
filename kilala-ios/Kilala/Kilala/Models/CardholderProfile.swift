//
//  CardholderProfile.swift
//  Kilala
//
//  Created by Joshua Calibo on 10/22/26.
//

import Foundation

struct CardholderProfile: Codable, Identifiable {
    let id: UUID
    let lguIdNumber: String
    let firstName: String
    let middleName: String?
    let lastName: String
    let dateOfBirth: String
    let sex: String
    let address: String
    let privilegeType: String
    let disabilityType: String?
    let status: String
    let qrSecretToken: String
    let lguName: String
    let expiryDate: String?
    
    var fullName: String {
        [firstName, middleName, lastName]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
