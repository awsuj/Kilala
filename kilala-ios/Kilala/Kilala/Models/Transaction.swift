//
//  Transaction.swift
//  Kilala
//
//  Created by Joshua Calibo on 10/24/26.
//

import Foundation

struct TransactionRecordRequest: Codable {
    let cardholderId: String
    let originalAmount: Double
    let discountedAmount: Double

    enum CodingKeys: String, CodingKey {
        case cardholderId = "cardholder_id"
        case originalAmount = "original_amount"
        case discountedAmount = "discounted_amount"
    }
}

struct TransactionRecordResponse: Codable, Identifiable {
    let message: String?
    let id: UUID
    let businessId: UUID
    let cardholderId: UUID
    let originalAmount: Double
    let discountedAmount: Double
    let createdAt: String
}

struct TransactionHistoryItem: Codable, Identifiable {
    let id: UUID
    let businessId: UUID?
    let cardholderId: UUID
    let cardholderName: String
    let firstName: String?
    let middleName: String?
    let lastName: String?
    let lguIdNumber: String?
    let privilegeType: String?
    let originalAmount: Double
    let discountedAmount: Double
    let createdAt: String
}
