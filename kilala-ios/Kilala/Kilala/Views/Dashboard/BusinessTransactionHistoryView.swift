//
//  BusinessTransactionHistoryView.swift
//  Kilala
//
//  Created by Joshua Calibo on 10/24/26.
//

import SwiftUI

struct BusinessTransactionHistoryView: View {
    var onLogout: (() -> Void)? = nil
    var showBrandLogo: Bool = false

    @State private var transactions: [TransactionHistoryItem] = []
    @State private var selectedTransaction: TransactionHistoryItem? = nil
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil

    var body: some View {
        ZStack {
            Color.kilalaPaper
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
                .padding(.bottom, 108)
            }
            .refreshable {
                await loadTransactions()
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                if showBrandLogo {
                    BusinessPortalHeader(title: "Transactions", onLogout: onLogout)
                }
            }
        }
        .navigationTitle("Transactions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(showBrandLogo ? .hidden : .visible, for: .navigationBar)
        .toolbarBackground(Color.kilalaPaper, for: .navigationBar)
        .toolbar {
            if !showBrandLogo, let onLogout = onLogout {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Logout", action: onLogout)
                        .font(.kilala(.subheadline, weight: .semibold))
                        .foregroundColor(.kilalaInk)
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
                    .font(.kilala(.caption, weight: .bold))
                    .tracking(0.8)
                    .foregroundColor(.kilalaInkSecondary)

                Spacer()

                Text("\(transactions.count) Verified")
                    .font(.kilala(.caption, weight: .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.kilalaStateValid.opacity(0.15))
                    .foregroundColor(.kilalaStateValid)
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
        .background(Color.kilalaMint)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.kilalaMintBorder, lineWidth: 1)
        )
    }

    // MARK: - Loading & Empty States

    private var loadingCard: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(.kilalaGreen)
            Text("Loading transactions...")
                .font(.kilala(.subheadline))
                .foregroundColor(.kilalaInkSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
        .background(Color.kilalaMint)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.kilalaMintBorder, lineWidth: 1)
        )
    }

    private var emptyStateCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "receipt")
                .font(.system(size: 36))
                .foregroundColor(.kilalaGreen.opacity(0.7))

            Text("No Transactions Yet")
                .font(.kilala(.headline, weight: .bold))
                .foregroundColor(.kilalaInk)

            Text("Recorded 20% statutory discount transactions will appear here.")
                .font(.kilala(.subheadline))
                .foregroundColor(.kilalaInkSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
        .background(Color.kilalaMint)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.kilalaMintBorder, lineWidth: 1)
        )
    }

    private func errorBanner(message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.circle")
                .font(.body.weight(.semibold))
                .foregroundColor(.kilalaStateInvalid)

            Text(message)
                .font(.kilala(.caption, weight: .medium))
                .foregroundColor(.kilalaInk)

            Spacer()

            Button("Retry") {
                Task {
                    await loadTransactions()
                }
            }
            .font(.kilala(.caption, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Color.kilalaGreen)
            .clipShape(Capsule())
            .shadow(color: Color.kilalaGreen.opacity(0.18), radius: 6, x: 0, y: 3)
        }
        .padding(14)
        .background(Color.kilalaMint)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.kilalaStateInvalid.opacity(0.30), lineWidth: 1)
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
                    .font(.kilala(.subheadline, weight: .bold))
                    .foregroundColor(.kilalaInk)
                    .lineLimit(1)

                if let cardNumber = item.lguIdNumber, !cardNumber.isEmpty {
                    Text(cardNumber)
                        .font(.kilalaMono(.caption, weight: .medium))
                        .foregroundColor(.kilalaInkSecondary)
                        .lineLimit(1)
                }

                Text(TransactionDateFormatting.formatShort(item.createdAt))
                    .font(.kilala(.caption))
                    .foregroundColor(.kilalaInkSecondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "₱%.2f", item.discountedAmount))
                    .font(.kilala(.subheadline, weight: .bold))
                    .foregroundColor(.kilalaInk)

                Text(String(format: "Orig: ₱%.2f", item.originalAmount))
                    .font(.kilala(.caption2, weight: .medium))
                    .foregroundColor(.kilalaInkSecondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundColor(.kilalaInkMuted)
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.kilalaMintBorder, lineWidth: 1)
        )
        .shadow(color: Color.kilalaInk.opacity(0.05), radius: 8, x: 0, y: 4)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Transaction Detail Sheet

struct TransactionDetailSheet: View {
    let transaction: TransactionHistoryItem
    @Environment(\.dismiss) private var dismiss

    private var verificationStatus: (label: String, icon: String, fill: Color, foreground: Color) {
        guard let rawStatus = transaction.status?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawStatus.isEmpty else {
            return ("Verified", "checkmark.seal.fill", Color.kilalaStateValid.opacity(0.15), .kilalaStateValid)
        }
        let upper = rawStatus.uppercased()
        if upper == "ACTIVE" || upper == "VERIFIED" {
            return ("Verified", "checkmark.seal.fill", Color.kilalaStateValid.opacity(0.15), .kilalaStateValid)
        }
        if upper == "EXPIRED" {
            return ("Expired", "clock.badge.exclamationmark.fill", .kilalaStateExpired, .kilalaInk)
        }
        return (rawStatus.capitalized, "xmark.octagon.fill", Color.kilalaStateInvalid.opacity(0.15), .kilalaStateInvalid)
    }

    private var classificationStyle: (fill: Color, foreground: Color) {
        switch transaction.privilegeType?.uppercased() {
        case "PWD":
            return (Color.kilalaGreen.opacity(0.14), .kilalaGreen)
        case "SENIOR_CITIZEN":
            return (Color.kilalaSunrise.opacity(0.32), .kilalaInk)
        default:
            return (Color.kilalaMint, .kilalaInkSecondary)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.kilalaPaper
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        // Cardholder & Verification Identity Card
                        VStack(spacing: 16) {
                            // Verification Status Badge
                            HStack(spacing: 6) {
                                Image(systemName: verificationStatus.icon)
                                    .font(.caption.weight(.semibold))
                                Text(verificationStatus.label)
                                    .font(.kilala(.caption, weight: .bold))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(verificationStatus.fill)
                            .foregroundColor(verificationStatus.foreground)
                            .clipShape(Capsule())

                            // Cardholder Name
                            VStack(spacing: 4) {
                                Text("CARDHOLDER")
                                    .font(.kilala(.caption, weight: .bold))
                                    .tracking(0.8)
                                    .foregroundColor(.kilalaInkSecondary)

                                Text(transaction.cardholderName)
                                    .font(.kilala(.title2, weight: .bold))
                                    .foregroundColor(.kilalaInk)
                                    .multilineTextAlignment(.center)
                            }

                            // Prominent Card Number (LGU ID Number)
                            VStack(spacing: 6) {
                                Text("CARD NUMBER (LGU ID)")
                                    .font(.kilala(.caption2, weight: .bold))
                                    .tracking(0.8)
                                    .foregroundColor(.kilalaInkSecondary)

                                Text(transaction.lguIdNumber?.isEmpty == false ? transaction.lguIdNumber! : "Not Available")
                                    .font(.kilalaMono(.title3, weight: .bold))
                                    .foregroundColor(.kilalaInk)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .padding(.horizontal, 16)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.kilalaMintBorder, lineWidth: 1)
                            )
                            .shadow(color: Color.kilalaInk.opacity(0.04), radius: 6, x: 0, y: 3)

                            // Metadata Breakdown Card
                            VStack(spacing: 12) {
                                HStack {
                                    Text("CLASSIFICATION")
                                        .font(.kilala(.caption, weight: .bold))
                                        .tracking(0.8)
                                        .foregroundColor(.kilalaInkSecondary)

                                    Spacer()

                                    Text(transaction.formattedPrivilegeType)
                                        .font(.kilala(.caption, weight: .bold))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(classificationStyle.fill)
                                        .foregroundColor(classificationStyle.foreground)
                                        .clipShape(Capsule())
                                }

                                if let lguName = transaction.lguName, !lguName.isEmpty {
                                    Divider()
                                        .overlay(Color.kilalaMintBorder)

                                    detailRow(label: "ISSUING LGU", value: lguName)
                                }

                                Divider()
                                    .overlay(Color.kilalaMintBorder)

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
                                    .stroke(Color.kilalaMintBorder, lineWidth: 1)
                            )
                            .shadow(color: Color.kilalaInk.opacity(0.04), radius: 6, x: 0, y: 3)
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity)
                        .background(Color.kilalaMint)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(Color.kilalaMintBorder, lineWidth: 1)
                        )

                        // Payment & Discount Breakdown Card
                        VStack(alignment: .leading, spacing: 14) {
                            Text("PAYMENT BREAKDOWN")
                                .font(.kilala(.caption, weight: .bold))
                                .tracking(0.8)
                                .foregroundColor(.kilalaInkSecondary)

                            VStack(spacing: 12) {
                                detailRow(
                                    label: "ORIGINAL BILL",
                                    value: String(format: "₱%.2f", transaction.originalAmount)
                                )

                                Divider()
                                    .overlay(Color.kilalaMintBorder)

                                HStack {
                                    Text("20% DISCOUNT")
                                        .font(.kilala(.caption, weight: .bold))
                                        .tracking(0.8)
                                        .foregroundColor(.kilalaInkSecondary)

                                    Spacer()

                                    Text(String(format: "-₱%.2f", transaction.discountAmount))
                                        .font(.kilala(.subheadline, weight: .bold))
                                        .foregroundColor(.kilalaStateValid)
                                }

                                Divider()
                                    .overlay(Color.kilalaMintBorder)

                                HStack {
                                    Text("FINAL AMOUNT")
                                        .font(.kilala(.caption, weight: .bold))
                                        .tracking(0.8)
                                        .foregroundColor(.kilalaInk)

                                    Spacer()

                                    Text(String(format: "₱%.2f", transaction.discountedAmount))
                                        .font(.kilala(.title3, weight: .bold))
                                        .foregroundColor(.kilalaGreen)
                                }
                            }
                            .padding(16)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.kilalaMintBorder, lineWidth: 1)
                            )
                            .shadow(color: Color.kilalaInk.opacity(0.04), radius: 6, x: 0, y: 3)
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.kilalaMint)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(Color.kilalaMintBorder, lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Transaction Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.kilalaPaper, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.kilala(.subheadline, weight: .semibold))
                    .foregroundColor(.kilalaGreen)
                }
            }
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(.kilala(.caption, weight: .bold))
                .tracking(0.8)
                .foregroundColor(.kilalaInkSecondary)

            Spacer()

            Text(value)
                .font(.kilala(.subheadline, weight: .semibold))
                .foregroundColor(.kilalaInk)
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
