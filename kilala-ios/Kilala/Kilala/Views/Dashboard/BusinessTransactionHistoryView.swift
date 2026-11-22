//
//  BusinessTransactionHistoryView.swift
//  Kilala
//
//  Created by Joshua Calibo on 10/24/26.
//

import SwiftUI

struct BusinessTransactionHistoryView: View {
    var onScanQR: (() -> Void)? = nil
    var onLogout: (() -> Void)? = nil

    @State private var transactions: [TransactionHistoryItem] = []
    @State private var selectedTransaction: TransactionHistoryItem? = nil
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil

    private static let darkGreenText = Color(red: 0.09, green: 0.48, blue: 0.22)
    private static let darkRedText = Color(red: 0.72, green: 0.14, blue: 0.14)

    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let errorMessage = errorMessage {
                        errorBanner(message: errorMessage)
                    }

                    if isLoading && transactions.isEmpty {
                        loadingCard
                    } else if transactions.isEmpty {
                        emptyStateCard
                    } else {
                        transactionsListCard
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .refreshable {
                await loadTransactions()
            }
        }
        .navigationTitle("Transactions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let onScanQR = onScanQR {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: onScanQR) {
                        HStack(spacing: 5) {
                            Image(systemName: "qrcode.viewfinder")
                            Text("Scan QR")
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                    }
                }
            }

            if let onLogout = onLogout {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Logout", action: onLogout)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                }
            }
        }
        .task {
            await loadTransactions()
        }
        .sheet(item: $selectedTransaction) { item in
            TransactionDetailSheet(transaction: item)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Transactions Card

    private var transactionsListCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 8) {
                Text("TRANSACTION HISTORY")
                    .font(.caption)
                    .fontWeight(.bold)
                    .tracking(0.8)
                    .foregroundColor(.gray)

                Spacer()

                Text("\(transactions.count) Verified")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.15))
                    .foregroundColor(Self.darkGreenText)
                    .clipShape(Capsule())
            }

            LazyVStack(spacing: 10) {
                ForEach(transactions) { item in
                    Button {
                        selectedTransaction = item
                    } label: {
                        TransactionHistoryRow(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.96))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.gray.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Loading & Empty States

    private var loadingCard: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading transactions...")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
        .background(Color(white: 0.96))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.gray.opacity(0.25), lineWidth: 1)
        )
    }

    private var emptyStateCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "receipt")
                .font(.system(size: 36))
                .foregroundColor(.gray)

            Text("No Transactions Yet")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.black)

            Text("Recorded 20% statutory discount transactions will appear here.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
        .background(Color(white: 0.96))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.gray.opacity(0.25), lineWidth: 1)
        )
    }

    private func errorBanner(message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.circle")
                .font(.body.weight(.semibold))
                .foregroundColor(Self.darkRedText)

            Text(message)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(Color(white: 0.30))

            Spacer()

            Button("Retry") {
                Task {
                    await loadTransactions()
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundColor(.black)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Color.white)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.gray.opacity(0.25), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
        }
        .padding(14)
        .background(Color(white: 0.96))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.gray.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Data Loading

    private func loadTransactions() async {
        isLoading = true
        errorMessage = nil

        do {
            transactions = try await APIService.shared.fetchBusinessTransactions()
            isLoading = false
        } catch is CancellationError {
            // Task cancelled
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

// MARK: - Reusable Tappable Transaction Row

struct TransactionHistoryRow: View {
    let item: TransactionHistoryItem

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.cardholderName)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                    .lineLimit(1)

                if let cardNumber = item.lguIdNumber, !cardNumber.isEmpty {
                    Text(cardNumber)
                        .font(.caption.monospaced())
                        .fontWeight(.medium)
                        .foregroundColor(Color(white: 0.40))
                        .lineLimit(1)
                }

                Text(TransactionDateFormatting.formatShort(item.createdAt))
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "₱%.2f", item.discountedAmount))
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.black)

                Text(String(format: "Orig: ₱%.2f", item.originalAmount))
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(Color(white: 0.40))
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundColor(Color(white: 0.65))
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.gray.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Transaction Detail Sheet

struct TransactionDetailSheet: View {
    let transaction: TransactionHistoryItem
    @Environment(\.dismiss) private var dismiss

    private static let darkGreenText = Color(red: 0.09, green: 0.48, blue: 0.22)
    private static let darkRedText = Color(red: 0.72, green: 0.14, blue: 0.14)
    private static let darkBlueText = Color(red: 0.13, green: 0.34, blue: 0.68)
    private static let darkAmberText = Color(red: 0.62, green: 0.38, blue: 0.05)

    private var verificationStatus: (label: String, isPositive: Bool) {
        guard let rawStatus = transaction.status?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawStatus.isEmpty else {
            return ("Verified", true)
        }
        let upper = rawStatus.uppercased()
        if upper == "ACTIVE" || upper == "VERIFIED" {
            return ("Verified", true)
        }
        return (rawStatus.capitalized, false)
    }

    private var classificationStyle: (fill: Color, foreground: Color) {
        switch transaction.privilegeType?.uppercased() {
        case "PWD":
            return (Color.blue.opacity(0.12), Self.darkBlueText)
        case "SENIOR_CITIZEN":
            return (Color.orange.opacity(0.14), Self.darkAmberText)
        default:
            return (Color(white: 0.92), Color(white: 0.30))
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        // Cardholder & Verification Identity Card
                        VStack(spacing: 16) {
                            // Soft Pastel Verification Status Badge
                            HStack(spacing: 6) {
                                Image(systemName: verificationStatus.isPositive ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                                    .font(.caption.weight(.semibold))
                                Text(verificationStatus.label)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(
                                verificationStatus.isPositive
                                    ? Color.green.opacity(0.15)
                                    : Color.red.opacity(0.15)
                            )
                            .foregroundColor(
                                verificationStatus.isPositive
                                    ? Self.darkGreenText
                                    : Self.darkRedText
                            )
                            .clipShape(Capsule())

                            // Cardholder Name
                            VStack(spacing: 4) {
                                Text("CARDHOLDER")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .tracking(0.8)
                                    .foregroundColor(.gray)

                                Text(transaction.cardholderName)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.black)
                                    .multilineTextAlignment(.center)
                            }

                            // Prominent Card Number (LGU ID Number)
                            VStack(spacing: 6) {
                                Text("CARD NUMBER (LGU ID)")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .tracking(0.8)
                                    .foregroundColor(.gray)

                                Text(transaction.lguIdNumber?.isEmpty == false ? transaction.lguIdNumber! : "Not Available")
                                    .font(.system(.title3, design: .monospaced))
                                    .fontWeight(.bold)
                                    .foregroundColor(.black)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .padding(.horizontal, 16)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)

                            // Metadata Breakdown Card
                            VStack(spacing: 12) {
                                HStack {
                                    Text("CLASSIFICATION")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .tracking(0.8)
                                        .foregroundColor(.gray)

                                    Spacer()

                                    Text(transaction.formattedPrivilegeType)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(classificationStyle.fill)
                                        .foregroundColor(classificationStyle.foreground)
                                        .clipShape(Capsule())
                                }

                                if let lguName = transaction.lguName, !lguName.isEmpty {
                                    Divider()
                                        .overlay(Color.gray.opacity(0.15))

                                    detailRow(label: "ISSUING LGU", value: lguName)
                                }

                                Divider()
                                    .overlay(Color.gray.opacity(0.15))

                                detailRow(
                                    label: "DATE & TIME",
                                    value: TransactionDateFormatting.formatFull(transaction.createdAt)
                                )
                            }
                            .padding(16)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity)
                        .background(Color(white: 0.96))
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                        )

                        // Payment & Discount Breakdown Card
                        VStack(alignment: .leading, spacing: 14) {
                            Text("PAYMENT BREAKDOWN")
                                .font(.caption)
                                .fontWeight(.bold)
                                .tracking(0.8)
                                .foregroundColor(.gray)

                            VStack(spacing: 12) {
                                detailRow(
                                    label: "ORIGINAL BILL",
                                    value: String(format: "₱%.2f", transaction.originalAmount)
                                )

                                Divider()
                                    .overlay(Color.gray.opacity(0.15))

                                HStack {
                                    Text("20% DISCOUNT")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .tracking(0.8)
                                        .foregroundColor(.gray)

                                    Spacer()

                                    Text(String(format: "-₱%.2f", transaction.discountAmount))
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(Self.darkGreenText)
                                }

                                Divider()
                                    .overlay(Color.gray.opacity(0.15))

                                HStack {
                                    Text("FINAL AMOUNT")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .tracking(0.8)
                                        .foregroundColor(.black)

                                    Spacer()

                                    Text(String(format: "₱%.2f", transaction.discountedAmount))
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(.black)
                                }
                            }
                            .padding(16)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(white: 0.96))
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Transaction Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                }
            }
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(.caption)
                .fontWeight(.bold)
                .tracking(0.8)
                .foregroundColor(.gray)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.black)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Date Formatting Helper

enum TransactionDateFormatting {
    private static let isoFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let isoStandard: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static func parse(_ isoString: String) -> Date? {
        isoFractional.date(from: isoString) ?? isoStandard.date(from: isoString)
    }

    static func formatShort(_ isoString: String) -> String {
        guard let date = parse(isoString) else { return isoString }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    static func formatFull(_ isoString: String) -> String {
        guard let date = parse(isoString) else { return isoString }
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
