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
    @State private var filterStartDate: Date? = nil
    @State private var filterEndDate: Date? = nil
    @State private var isShowingDatePicker: Bool = false
    @State private var selectedTransaction: TransactionHistoryItem? = nil
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil

    private var hasActiveDateFilter: Bool {
        filterStartDate != nil && filterEndDate != nil
    }

    private var activeDateRangeLabel: String? {
        guard let start = filterStartDate, let end = filterEndDate else { return nil }
        return TransactionDateFormatting.formatRange(start: start, end: end)
    }

    private var filteredTransactions: [TransactionHistoryItem] {
        var result = transactions

        if let start = filterStartDate, let end = filterEndDate {
            let calendar = Calendar.current
            let rangeStart = calendar.startOfDay(for: min(start, end))
            let endDayStart = calendar.startOfDay(for: max(start, end))
            let rangeEndExclusive = calendar.date(byAdding: .day, value: 1, to: endDayStart) ?? max(start, end)

            result = result.filter { item in
                guard let txDate = TransactionDateFormatting.parse(item.createdAt) else {
                    return false
                }
                return txDate >= rangeStart && txDate < rangeEndExclusive
            }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return result }
        return result.filter { item in
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

                    // Search & Date Filter Bar (12pt radius)
                    VStack(alignment: .leading, spacing: 10) {
                        searchBar

                        if let rangeLabel = activeDateRangeLabel {
                            activeDateFilterChip(label: rangeLabel)
                        }
                    }

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
        .sheet(isPresented: $isShowingDatePicker) {
            TransactionDateRangeSheet(
                initialStartDate: filterStartDate,
                initialEndDate: filterEndDate,
                onReset: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        filterStartDate = nil
                        filterEndDate = nil
                    }
                    Task {
                        await loadTransactions()
                    }
                },
                onApply: { start, end in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        filterStartDate = start
                        filterEndDate = end
                    }
                    Task {
                        await loadTransactions()
                    }
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(16)
            .presentationBackground(Color.kilalaPaper)
        }
        .sheet(item: $selectedTransaction) { item in
            TransactionDetailSheet(transaction: item)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Search & Date Filter

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

            Rectangle()
                .fill(Color.kilalaMintBorder)
                .frame(width: 1, height: 22)
                .accessibilityHidden(true)

            Button {
                isShowingDatePicker = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: hasActiveDateFilter ? "calendar.badge.clock" : "calendar")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(hasActiveDateFilter ? .kilalaGreen : .kilalaInk)
                        .frame(width: 34, height: 34)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(hasActiveDateFilter ? Color.kilalaGreen.opacity(0.12) : Color.kilalaPaper)
                        )

                    if hasActiveDateFilter {
                        Circle()
                            .fill(Color.kilalaSunrise)
                            .frame(width: 8, height: 8)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 1.5)
                            )
                            .offset(x: 2, y: -2)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(hasActiveDateFilter ? "Date filter active" : "Filter by date range")
            .accessibilityHint("Opens date range selector")
        }
        .padding(.leading, 12)
        .padding(.trailing, 6)
        .frame(minHeight: 46)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(hasActiveDateFilter ? Color.kilalaGreen.opacity(0.45) : Color.kilalaMintBorder, lineWidth: 1)
        )
    }

    private func activeDateFilterChip(label: String) -> some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.kilalaGreen)
                    .accessibilityHidden(true)

                Text(label)
                    .font(.kilala(.footnote, weight: .bold))
                    .foregroundColor(.kilalaInk)
                    .lineLimit(1)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        filterStartDate = nil
                        filterEndDate = nil
                    }
                    Task {
                        await loadTransactions()
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.kilalaGreen)
                        .frame(width: 20, height: 20)
                        .background(Color.kilalaGreen.opacity(0.14))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear date filter")
            }
            .padding(.leading, 10)
            .padding(.trailing, 6)
            .padding(.vertical, 6)
            .background(Color.kilalaMint)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.kilalaMintBorder, lineWidth: 1)
            )

            Spacer(minLength: 0)
        }
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
        let hasAnyFilter = isSearching || hasActiveDateFilter

        let iconName: String = {
            if isSearching { return "magnifyingglass" }
            if hasActiveDateFilter { return "calendar.badge.exclamationmark" }
            return "receipt"
        }()

        let titleText: String = {
            if hasAnyFilter { return "No matching transactions" }
            return "No Transactions Yet"
        }()

        let subtitleText: String = {
            if isSearching && hasActiveDateFilter {
                return "Try adjusting your search query or selected date range."
            } else if hasActiveDateFilter {
                return "No transactions were recorded in the selected date range."
            } else if isSearching {
                return "Try a different cardholder name or LGU ID number."
            } else {
                return "Recorded 20% statutory discount transactions will appear here."
            }
        }()

        return VStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 28))
                .foregroundColor(.kilalaInkMuted)
                .accessibilityHidden(true)

            Text(titleText)
                .font(.kilala(.headline, weight: .bold))
                .foregroundColor(.kilalaInk)

            Text(subtitleText)
                .font(.kilala(.subheadline))
                .foregroundColor(.kilalaInkSecondary)
                .multilineTextAlignment(.center)

            if hasActiveDateFilter {
                Button("Reset Date Filter") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        filterStartDate = nil
                        filterEndDate = nil
                    }
                    Task {
                        await loadTransactions()
                    }
                }
                .font(.kilala(.footnote, weight: .bold))
                .foregroundColor(.kilalaGreen)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.kilalaMint)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(.top, 6)
            }
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
            transactions = try await APIService.shared.fetchBusinessTransactions(
                startDate: filterStartDate,
                endDate: filterEndDate
            )
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

// MARK: - Date Range Picker Sheet (Paper-and-Mint)

private struct TransactionDateRangeSheet: View {
    enum DatePreset: String, CaseIterable, Identifiable {
        case today = "Today"
        case yesterday = "Yesterday"
        case thisWeek = "This Week"
        case thisMonth = "This Month"

        var id: String { rawValue }

        func dateRange(calendar: Calendar = .current, now: Date = Date()) -> (start: Date, end: Date) {
            let todayStart = calendar.startOfDay(for: now)
            switch self {
            case .today:
                return (todayStart, now)
            case .yesterday:
                let yesterday = calendar.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart
                return (yesterday, yesterday)
            case .thisWeek:
                let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? todayStart
                return (weekStart, now)
            case .thisMonth:
                let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? todayStart
                return (monthStart, now)
            }
        }
    }

    let initialStartDate: Date?
    let initialEndDate: Date?
    let onReset: () -> Void
    let onApply: (Date, Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draftStartDate: Date
    @State private var draftEndDate: Date

    init(
        initialStartDate: Date?,
        initialEndDate: Date?,
        onReset: @escaping () -> Void,
        onApply: @escaping (Date, Date) -> Void
    ) {
        self.initialStartDate = initialStartDate
        self.initialEndDate = initialEndDate
        self.onReset = onReset
        self.onApply = onApply

        let today = Date()
        let start = min(initialStartDate ?? today, today)
        let end = min(max(initialEndDate ?? today, start), today)
        _draftStartDate = State(initialValue: start)
        _draftEndDate = State(initialValue: end)
    }

    private func isPresetSelected(_ preset: DatePreset) -> Bool {
        let calendar = Calendar.current
        let range = preset.dateRange(calendar: calendar)
        return calendar.isDate(draftStartDate, inSameDayAs: range.start)
            && calendar.isDate(draftEndDate, inSameDayAs: range.end)
    }

    var body: some View {
        ZStack {
            Color.kilalaPaper
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                // Sheet Header
                HStack(alignment: .center, spacing: 12) {
                    Text("Select Date Range")
                        .font(.kilala(size: 20, weight: .bold, relativeTo: .title3))
                        .foregroundColor(.kilalaInk)

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.kilalaInkSecondary)
                            .frame(width: 32, height: 32)
                            .background(Color.white)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.kilalaMintBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                }

                // Quick-Select Preset Chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(DatePreset.allCases) { preset in
                            let selected = isPresetSelected(preset)
                            Button {
                                let range = preset.dateRange()
                                draftStartDate = range.start
                                draftEndDate = range.end
                            } label: {
                                Text(preset.rawValue)
                                    .font(.kilala(.footnote, weight: .bold))
                                    .foregroundColor(selected ? .white : .kilalaInk)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(selected ? Color.kilalaGreen : Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(selected ? Color.kilalaGreen : Color.kilalaMintBorder, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }

                // Start & End Date Pickers Card (16pt Paper-and-Mint Container)
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Label("Start Date", systemImage: "calendar")
                            .font(.kilala(.callout, weight: .semibold))
                            .foregroundColor(.kilalaInk)

                        Spacer()

                        DatePicker(
                            "Start Date",
                            selection: $draftStartDate,
                            in: ...Date(),
                            displayedComponents: .date
                        )
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .tint(.kilalaGreen)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    Divider()
                        .overlay(Color.kilalaMintBorder)
                        .padding(.leading, 16)

                    HStack(spacing: 12) {
                        Label("End Date", systemImage: "calendar.badge.clock")
                            .font(.kilala(.callout, weight: .semibold))
                            .foregroundColor(.kilalaInk)

                        Spacer()

                        DatePicker(
                            "End Date",
                            selection: $draftEndDate,
                            in: ...Date(),
                            displayedComponents: .date
                        )
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .tint(.kilalaGreen)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.kilalaMintBorder, lineWidth: 1)
                )

                Spacer(minLength: 4)

                // Reset & Apply Actions
                HStack(spacing: 12) {
                    Button {
                        onReset()
                        dismiss()
                    } label: {
                        Text("Reset Filter")
                            .font(.kilala(.callout, weight: .bold))
                            .foregroundColor(.kilalaInk)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 48)
                            .background(Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.kilalaMintBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        let start = min(draftStartDate, draftEndDate)
                        let end = max(draftStartDate, draftEndDate)
                        onApply(start, end)
                        dismiss()
                    } label: {
                        Text("Apply Filter")
                            .font(.kilala(.callout, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 48)
                            .background(Color.kilalaGreen)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
        }
        .onChange(of: draftStartDate) { _, newStart in
            if newStart > draftEndDate {
                draftEndDate = newStart
            }
        }
        .onChange(of: draftEndDate) { _, newEnd in
            if newEnd < draftStartDate {
                draftStartDate = newEnd
            }
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

    static func parse(_ isoString: String) -> Date? {
        isoFractional.date(from: isoString) ?? isoStandard.date(from: isoString)
    }

    static func formatRange(start: Date, end: Date) -> String {
        let calendar = Calendar.current
        let orderedStart = min(start, end)
        let orderedEnd = max(start, end)

        let currentYear = calendar.component(.year, from: Date())
        let startYear = calendar.component(.year, from: orderedStart)
        let endYear = calendar.component(.year, from: orderedEnd)
        let includeYear = startYear != currentYear || endYear != currentYear

        let formatter = DateFormatter()
        formatter.dateFormat = includeYear ? "MMM d, yyyy" : "MMM d"

        if calendar.isDate(orderedStart, inSameDayAs: orderedEnd) {
            return formatter.string(from: orderedStart)
        }
        return "\(formatter.string(from: orderedStart)) – \(formatter.string(from: orderedEnd))"
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
