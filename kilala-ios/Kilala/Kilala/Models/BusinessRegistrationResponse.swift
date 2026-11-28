//
//  BusinessRegistrationResponse.swift
//  Kilala
//
//  Created by Joshua Calibo on 10/23/26.
//

import Foundation

struct BusinessRegistrationResponse: Codable {
    let message: String
    let token: String
    let user: User
    let businessProfile: BusinessProfile
}

struct BusinessVerificationResponse: Codable {
    let message: String
    let businessId: UUID
    let lguId: UUID
    let lguName: String?
    let lguCode: String?
    let businessName: String
    let branchName: String?
    let category: String?
    let businessPermitNo: String?
    let tinNumber: String
    let address: String?
    let isAccredited: Bool
}
