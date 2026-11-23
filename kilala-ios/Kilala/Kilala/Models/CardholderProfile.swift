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
    var issuedDate: String? = nil
    var issueDate: String? = nil
    var issuingLgu: String? = nil
    var photoUrl: String? = nil
    var profilePhotoUrl: String? = nil
    var contactNumber: String? = nil
    var emergencyContactName: String? = nil
    var emergencyContactPhone: String? = nil
    var emergencyContactNumber: String? = nil
    var email: String? = nil
    
    var fullName: String {
        [firstName, middleName, lastName]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    var resolvedIssuingLGU: String {
        let candidate = (issuingLgu ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return candidate.isEmpty ? lguName : candidate
    }

    var resolvedIssueDate: String? {
        issueDate ?? issuedDate
    }

    var resolvedPhotoURL: String? {
        photoUrl ?? profilePhotoUrl
    }

    var resolvedEmergencyContactNumber: String {
        (emergencyContactNumber ?? emergencyContactPhone ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var formattedPrivilegeType: String {
        switch privilegeType.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
        case "PWD":
            return "PWD"
        case "SENIOR_CITIZEN":
            return "Senior Citizen"
        default:
            return privilegeType
        }
    }

    var isPWD: Bool {
        privilegeType.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == "PWD"
    }
}
