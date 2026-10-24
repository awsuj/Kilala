//
//  BusinessTransactionHistoryView.swift
//  Kilala
//
//  Created by Joshua Calibo on 10/24/26.
//

import SwiftUI

struct BusinessTransactionHistoryView: View {
    @State private var transactions: [TransactionHistoryItem] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        Group {
            if isLoading && transactions.isEmpty {
                ProgressView("Loading transaction history...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = errorMessage, transactions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task {
                            await loadTransactions()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if transactions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "receipt")
                        .font(.system(size: 44))
                        .foregroundColor(.secondary)
                    Text("No Transactions Yet")
                        .font(.headline)
                    Text("Recorded 20% discount transactions will appear here.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(transactions) { item in
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.cardholderName)
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text(formatDate(item.createdAt))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(String(format: "₱%.2f", item.discountedAmount))
                                .font(.headline.weight(.bold))
                                .foregroundColor(.green)
                            
                            Text(String(format: "Orig: ₱%.2f", item.originalAmount))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.insetGrouped)
                .refreshable {
                    await loadTransactions()
                }
            }
        }
        .navigationTitle("Transaction History")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadTransactions()
        }
    }
    
    private func loadTransactions() async {
        isLoading = true
        errorMessage = nil
        
        do {
            transactions = try await APIService.shared.fetchBusinessTransactions()
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    private func formatDate(_ isoString: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let fallbackFormatter = ISO8601DateFormatter()
        fallbackFormatter.formatOptions = [.withInternetDateTime]
        
        if let date = isoFormatter.date(from: isoString) ?? fallbackFormatter.date(from: isoString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return isoString
    }
}
