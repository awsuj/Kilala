//
//  BusinessProfile.swift
//  Kilala
//
//  Created by Joshua Calibo on 10/23/26.
//

import Foundation

struct BusinessProfile: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let lguId: UUID
    let businessName: String
    let branchName: String?
    let category: String
    let businessPermitNo: String
    let tinNumber: String
    let address: String
    let isAccredited: Bool
    let createdAt: String?
    let updatedAt: String?
}
