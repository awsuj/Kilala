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

enum DashboardTimeframe: String, CaseIterable, Identifiable {
    case past24Hours = "24h"
    case pastWeek = "week"
    case pastMonth = "month"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .past24Hours:
            return "Past 24 Hours"
        case .pastWeek:
            return "Past Week"
        case .pastMonth:
            return "Past Month"
        }
    }
}

struct BusinessDashboardSummary: Codable {
    let range: String?
    let totalDiscountedAmount: Double
    let totalDiscountedSales: Double
    let totalOriginalAmount: Double?
    let transactionCount: Int?
    let transactions: [TransactionHistoryItem]?
}
