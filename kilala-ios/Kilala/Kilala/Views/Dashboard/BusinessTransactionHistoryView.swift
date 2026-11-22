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
    @State private var searchText: String = ""
    @State private var selectedTransaction: TransactionHistoryItem? = nil
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil

    private var filteredTransactions: [TransactionHistoryItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return transactions }
        return transactions.filter { item in
            item.cardholderName.localizedCaseInsensitiveContains(query) ||
            (item.lguIdNumber?.localizedCaseInsensitiveContains(query) ?? false) ||
            item.formattedPrivilegeType.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        ZStack {
            Color.kilalaPaper
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    if showBrandLogo {
                        BusinessPortalHeader(title: "Transactions")
                    }

                    // Search Filter (12pt radius)
                    searchBar

                    if let errorMessage = errorMessage {
                        errorBanner(message: errorMessage)
                    }

                    if isLoading && transactions.isEmpty {
                        loadingCard
                    } else if filteredTransactions.isEmpty {
                        emptyStateCard
                    } else {
                        transactionsListSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 96)
            }
            .scrollDismissesKeyboard(.interactively)
            .refreshable {
                await loadTransactions()
            }
        }
        .navigationTitle("Transactions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(showBrandLogo ? .hidden : .visible, for: .navigationBar)
        .toolbarBackground(Color.kilalaPaper, for: .navigationBar)
        .task {
            await loadTransactions()
        }
        .sheet(item: $selectedTransaction) { item in
            TransactionDetailSheet(transaction: item)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Search Filter

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.kilalaInkSecondary)
                .accessibilityHidden(true)

            TextField("Search by name or ID number", text: $searchText)
                .font(.kilala(.callout))
                .foregroundColor(.kilalaInk)
                .tint(.kilalaGreen)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.kilalaInkMuted)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 46)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.kilalaMintBorder, lineWidth: 1)
        )
    }

    // MARK: - Unified Transactions List Card

    private var transactionsListSection: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(filteredTransactions.enumerated()), id: \.element.id) { index, item in
                Button {
                    selectedTransaction = item
                } label: {
                    TransactionHistoryRow(item: item, showCardNumber: false)
                }
                .buttonStyle(.plain)

                if index < filteredTransactions.count - 1 {
                    Divider()
                        .overlay(Color.kilalaMintBorder)
                        .padding(.leading, 16)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.kilalaMintBorder, lineWidth: 1)
        )
    }

    // MARK: - Loading, Empty & Error States

    private var loadingCard: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(.kilalaGreen)
            Text("Loading transactions...")
                .font(.kilala(.callout))
                .foregroundColor(.kilalaInkSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, 16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.kilalaMintBorder, lineWidth: 1)
        )
    }

    private var emptyStateCard: some View {
        let isSearching = !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return VStack(spacing: 8) {
            Image(systemName: isSearching ? "magnifyingglass" : "receipt")
                .font(.system(size: 28))
                .foregroundColor(.kilalaInkMuted)
                .accessibilityHidden(true)

            Text(isSearching ? "No matching transactions" : "No Transactions Yet")
                .font(.kilala(.headline, weight: .bold))
                .foregroundColor(.kilalaInk)

            Text(
                isSearching
                    ? "Try a different cardholder name or LGU ID number."
                    : "Recorded 20% statutory discount transactions will appear here."
            )
            .font(.kilala(.subheadline))
            .foregroundColor(.kilalaInkSecondary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, 16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.kilalaMintBorder, lineWidth: 1)
        )
    }

    private func errorBanner(message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.kilalaStateInvalid)
                .accessibilityHidden(true)

            Text(message)
                .font(.kilala(.footnote, weight: .semibold))
                .foregroundColor(.kilalaInk)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            Button("Retry") {
                Task {
                    await loadTransactions()
                }
            }
            .font(.kilala(.footnote, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .frame(minHeight: 34)
            .background(Color.kilalaGreen)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.kilalaStateInvalid.opacity(0.35), lineWidth: 1)
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

// MARK: - Reusable Flat Transaction Row (Used inside 16pt White List Container)

struct TransactionHistoryRow: View {
    let item: TransactionHistoryItem
    var showCardNumber: Bool = false

    private var formattedTimestamp: String {
        TransactionDateFormatting.formatCompact(item.createdAt)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.cardholderName)
                    .font(.kilala(size: 16, weight: .bold, relativeTo: .callout))
                    .foregroundColor(.kilalaInk)
                    .lineLimit(1)

                metadataLine
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "₱%.2f", item.discountedAmount))
                    .font(.kilala(size: 16, weight: .bold, relativeTo: .callout))
                    .foregroundColor(.kilalaInk)
                    .lineLimit(1)

                Text(String(format: "From ₱%.2f", item.originalAmount))
                    .font(.kilala(size: 13, weight: .regular, relativeTo: .footnote))
                    .foregroundColor(.kilalaInkSecondary)
                    .lineLimit(1)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.kilalaInkMuted)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .frame(minHeight: 60)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var metadataLine: some View {
        if showCardNumber, let cardNumber = item.lguIdNumber, !cardNumber.isEmpty {
            (
                Text(cardNumber)
                    .font(.kilalaMono(size: 13, weight: .medium))
                + Text(" · \(formattedTimestamp)")
                    .font(.kilala(size: 13, weight: .regular, relativeTo: .footnote))
            )
            .foregroundColor(.kilalaInkSecondary)
            .lineLimit(1)
            .truncationMode(.tail)
        } else {
            Text(formattedTimestamp)
                .font(.kilala(size: 13, weight: .regular, relativeTo: .footnote))
                .foregroundColor(.kilalaInkSecondary)
                .lineLimit(1)
        }
    }
}

// MARK: - Transaction Detail Sheet (Single Crisp 16pt White Audit Card)

struct TransactionDetailSheet: View {
    let transaction: TransactionHistoryItem
    @Environment(\.dismiss) private var dismiss

    private var verificationStatus: (label: String, icon: String, fill: Color, foreground: Color) {
        guard let rawStatus = transaction.status?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawStatus.isEmpty else {
            return ("Verified", "checkmark.seal.fill", Color.kilalaStateValid.opacity(0.12), .kilalaStateValid)
        }
        let upper = rawStatus.uppercased()
        if upper == "ACTIVE" || upper == "VERIFIED" {
            return ("Verified", "checkmark.seal.fill", Color.kilalaStateValid.opacity(0.12), .kilalaStateValid)
        }
        if upper == "EXPIRED" {
            return ("Expired", "clock.badge.exclamationmark.fill", .kilalaStateExpired, .kilalaInk)
        }
        return (rawStatus.capitalized, "xmark.octagon.fill", Color.kilalaStateInvalid.opacity(0.12), .kilalaStateInvalid)
    }

    private var classificationBadge: (icon: String, fill: Color, foreground: Color) {
        switch transaction.privilegeType?.uppercased() {
        case "PWD":
            return ("figure.roll", Color.kilalaGreen.opacity(0.12), .kilalaGreen)
        case "SENIOR_CITIZEN":
            return ("person.crop.circle.badge.checkmark", Color.kilalaSunrise.opacity(0.30), .kilalaInk)
        default:
            return ("person.text.rectangle", Color.kilalaMint, .kilalaInk)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.kilalaPaper
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    // Single Flat White 16pt Audit Card (No Nested Cards)
                    VStack(alignment: .leading, spacing: 16) {
                        // Verification Status Header (Icon + Word + Brand State Color)
                        HStack {
                            KilalaStatusBadge(
                                icon: verificationStatus.icon,
                                label: verificationStatus.label,
                                foreground: verificationStatus.foreground,
                                background: verificationStatus.fill,
                                cornerRadius: 8
                            )

                            Spacer()
                        }

                        // Cardholder Identity
                        VStack(alignment: .leading, spacing: 4) {
                            Text("CARDHOLDER")
                                .font(.kilala(.caption, weight: .bold))
                                .tracking(0.8)
                                .foregroundColor(.kilalaInkSecondary)

                            Text(transaction.cardholderName)
                                .font(.kilala(size: 22, weight: .bold, relativeTo: .title2))
                                .foregroundColor(.kilalaInk)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        // Prominent Monospaced Card / LGU ID Number (Tinted strip, not a card)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("CARD / LGU ID NUMBER")
                                .font(.kilala(.caption, weight: .bold))
                                .tracking(0.8)
                                .foregroundColor(.kilalaInkSecondary)

                            Text(transaction.lguIdNumber?.isEmpty == false ? transaction.lguIdNumber! : "Not Available")
                                .font(.kilalaMono(.title3, weight: .bold))
                                .foregroundColor(.kilalaInk)
                                .textSelection(.enabled)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color.kilalaPaper)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                        Divider()
                            .overlay(Color.kilalaMintBorder)

                        // Audit Metadata Rows
                        VStack(spacing: 12) {
                            HStack(alignment: .center) {
                                Text("Classification")
                                    .font(.kilala(.subheadline))
                                    .foregroundColor(.kilalaInkSecondary)

                                Spacer()

                                KilalaStatusBadge(
                                    icon: classificationBadge.icon,
                                    label: transaction.formattedPrivilegeType,
                                    foreground: classificationBadge.foreground,
                                    background: classificationBadge.fill,
                                    cornerRadius: 8
                                )
                            }

                            if let lguName = transaction.lguName, !lguName.isEmpty {
                                detailRow(label: "Issuing LGU", value: lguName)
                            }

                            detailRow(
                                label: "Timestamp",
                                value: TransactionDateFormatting.formatFull(transaction.createdAt)
                            )
                        }

                        Divider()
                            .overlay(Color.kilalaMintBorder)

                        // Payment & Discount Audit Breakdown
                        VStack(spacing: 12) {
                            detailRow(
                                label: "Gross Amount",
                                value: String(format: "₱%.2f", transaction.originalAmount)
                            )

                            HStack(alignment: .firstTextBaseline) {
                                Text("20% Discount Granted")
                                    .font(.kilala(.subheadline))
                                    .foregroundColor(.kilalaInkSecondary)

                                Spacer()

                                Text(String(format: "−₱%.2f", transaction.discountAmount))
                                    .font(.kilala(.callout, weight: .bold))
                                    .foregroundColor(.kilalaGreen)
                            }

                            Divider()
                                .overlay(Color.kilalaMintBorder)

                            HStack(alignment: .firstTextBaseline) {
                                Text("Net Collected")
                                    .font(.kilala(.callout, weight: .bold))
                                    .foregroundColor(.kilalaInk)

                                Spacer()

                                Text(String(format: "₱%.2f", transaction.discountedAmount))
                                    .font(.kilala(size: 22, weight: .bold, relativeTo: .title2))
                                    .foregroundColor(.kilalaInk)
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.kilalaMintBorder, lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
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
                    .font(.kilala(.subheadline, weight: .bold))
                    .foregroundColor(.kilalaGreen)
                }
            }
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(.kilala(.subheadline))
                .foregroundColor(.kilalaInkSecondary)

            Spacer()

            Text(value)
                .font(.kilala(.callout, weight: .semibold))
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

    static func formatCompact(_ isoString: String) -> String {
        guard let date = parse(isoString) else { return isoString }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter.string(from: date)
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
