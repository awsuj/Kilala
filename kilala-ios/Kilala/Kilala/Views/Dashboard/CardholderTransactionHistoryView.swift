//
//  CardholderTransactionHistoryView.swift
//  Kilala
//
//  Created by Eunice Santos on 11/23/26.
//

import SwiftUI

struct CardholderTransactionHistoryView: View {
    var token: String = APIService.shared.authToken ?? ""
    var onLogout: (() -> Void)? = nil
    var showBrandLogo: Bool = true

    @State private var transactions: [CardholderTransactionHistoryItem] = []
    @State private var searchText: String = ""
    @State private var filterStartDate: Date? = nil
    @State private var filterEndDate: Date? = nil
    @State private var isShowingDatePicker: Bool = false
    @State private var selectedTransaction: CardholderTransactionHistoryItem? = nil
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil

    private var hasActiveDateFilter: Bool {
        filterStartDate != nil && filterEndDate != nil
    }

    private var activeDateRangeLabel: String? {
        guard let start = filterStartDate, let end = filterEndDate else { return nil }
        return TransactionDateFormatting.formatRange(start: start, end: end)
    }

    private var filteredTransactions: [CardholderTransactionHistoryItem] {
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
            item.businessName.localizedCaseInsensitiveContains(query) ||
            (item.branchName?.localizedCaseInsensitiveContains(query) ?? false) ||
            item.formattedCategory.localizedCaseInsensitiveContains(query)
        }
    }

    private var groupedTransactions: [CardholderTransactionDateGroup] {
        Self.groupByDate(filteredTransactions)
    }

    private static func groupByDate(
        _ items: [CardholderTransactionHistoryItem],
        calendar: Calendar = .current
    ) -> [CardholderTransactionDateGroup] {
        var buckets: [Date: [(item: CardholderTransactionHistoryItem, timestamp: Date)]] = [:]

        for item in items {
            let parsedDate = TransactionDateFormatting.parse(item.createdAt) ?? Date.distantPast
            let dayStart = calendar.startOfDay(for: parsedDate)
            buckets[dayStart, default: []].append((item: item, timestamp: parsedDate))
        }

        return buckets
            .sorted { $0.key > $1.key }
            .map { dayStart, entries in
                let sortedItems = entries
                    .sorted { $0.timestamp > $1.timestamp }
                    .map(\.item)
                return CardholderTransactionDateGroup(
                    date: dayStart,
                    title: TransactionDateFormatting.sectionHeaderTitle(for: dayStart, calendar: calendar),
                    items: sortedItems
                )
            }
    }

    var body: some View {
        ZStack {
            Color.kilalaPaper
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Fixed Header & Search/Calendar Bar above ScrollView
                VStack(alignment: .leading, spacing: 14) {
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
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .background(Color.kilalaPaper)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        if let errorMessage = errorMessage {
                            errorBanner(message: errorMessage)
                                .padding(.top, 8)
                        }

                        if isLoading && transactions.isEmpty {
                            loadingCard
                                .padding(.top, 8)
                        } else if filteredTransactions.isEmpty {
                            emptyStateCard
                                .padding(.top, 8)
                        } else {
                            transactionsListSection
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 96)
                }
                .scrollDismissesKeyboard(.interactively)
                .refreshable {
                    await loadTransactions()
                }
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
            CardholderTransactionDateRangeSheet(
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
            CardholderTransactionDetailSheet(transaction: item)
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

            TextField("Search by merchant name", text: $searchText)
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

    // MARK: - Chronological Date-Grouped Timeline

    private var transactionsListSection: some View {
        CardholderChronologicalTransactionList(groups: groupedTransactions) { item in
            selectedTransaction = item
        }
    }

    // MARK: - Loading, Empty & Error States

    private var loadingCard: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.kilalaMint)
                .frame(height: 1)

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
        }
        .background(Color.kilalaPaper)
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
            return "No verified discounts in this period"
        }()

        let subtitleText: String = {
            if isSearching && hasActiveDateFilter {
                return "Try adjusting your search query or selected date range."
            } else if hasActiveDateFilter {
                return "No transactions were recorded in the selected date range."
            } else if isSearching {
                return "Try a different merchant name or category."
            } else {
                return "Recorded 20% statutory discount transactions will appear here."
            }
        }()

        return VStack(spacing: 0) {
            Rectangle()
                .fill(Color.kilalaMint)
                .frame(height: 1)

            VStack(spacing: 8) {
                Image(systemName: iconName)
                    .font(.system(size: 28))
                    .foregroundColor(.kilalaInkMuted)
                    .accessibilityHidden(true)

                Text(titleText)
                    .font(.kilala(.headline, weight: .bold))
                    .foregroundColor(.kilalaInk)
                    .multilineTextAlignment(.center)

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
        }
        .background(Color.kilalaPaper)
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
            let activeToken = token.isEmpty ? (APIService.shared.authToken ?? "") : token
            transactions = try await APIService.shared.fetchCardholderTransactions(
                token: activeToken,
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

// MARK: - Chronological Date-Grouped Timeline (Paper-and-Mint)

struct CardholderTransactionDateGroup: Identifiable {
    let date: Date
    let title: String
    let items: [CardholderTransactionHistoryItem]

    var id: Date { date }
}

struct CardholderChronologicalTransactionList: View {
    let groups: [CardholderTransactionDateGroup]
    let onSelect: (CardholderTransactionHistoryItem) -> Void

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
            ForEach(groups) { group in
                Section {
                    VStack(spacing: 0) {
                        ForEach(Array(group.items.enumerated()), id: \.element.id) { itemIndex, item in
                            Button {
                                onSelect(item)
                            } label: {
                                CardholderTransactionHistoryRow(
                                    item: item,
                                    showTimeOnly: true,
                                    horizontalPadding: 16
                                )
                            }
                            .buttonStyle(.plain)

                            if itemIndex < group.items.count - 1 {
                                Rectangle()
                                    .fill(Color.kilalaMintBorder)
                                    .frame(height: 1)
                                    .padding(.leading, 16)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.kilalaMintBorder, lineWidth: 1)
                    )
                    .padding(.top, 8)
                    .padding(.bottom, 6)
                } header: {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(group.title)
                            .font(.kilala(size: 17, weight: .bold, relativeTo: .headline))
                            .foregroundColor(.kilalaGreen)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 14)
                            .padding(.bottom, 8)

                        Rectangle()
                            .fill(Color.kilalaMintBorder)
                            .frame(height: 1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.kilalaPaper)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.kilalaPaper)
    }
}

// MARK: - Reusable Flat Transaction Row (Inside White Date-Group Container)

struct CardholderTransactionHistoryRow: View {
    let item: CardholderTransactionHistoryItem
    var showTimeOnly: Bool = true
    var horizontalPadding: CGFloat = 16

    private var formattedTimestamp: String {
        showTimeOnly
            ? TransactionDateFormatting.formatTimeOnly(item.createdAt)
            : TransactionDateFormatting.formatCompact(item.createdAt)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.businessName)
                    .font(.kilala(size: 16, weight: .bold, relativeTo: .callout))
                    .foregroundColor(.kilalaInk)
                    .lineLimit(1)

                Text(formattedTimestamp)
                    .font(.kilala(size: 13, weight: .regular, relativeTo: .footnote))
                    .foregroundColor(.kilalaInkSecondary)
                    .lineLimit(1)
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
        .padding(.horizontal, horizontalPadding)
        .frame(minHeight: 60)
        .contentShape(Rectangle())
    }
}

// MARK: - Cardholder Transaction Detail Sheet (Single Crisp 16pt White Audit Card)

struct CardholderTransactionDetailSheet: View {
    let transaction: CardholderTransactionHistoryItem
    @Environment(\.dismiss) private var dismiss

    private var branchDisplayText: String {
        if let branch = transaction.branchName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !branch.isEmpty {
            return branch
        }
        return "Main Branch"
    }

    private var categoryBadge: (icon: String, fill: Color, foreground: Color) {
        let raw = (transaction.category ?? transaction.businessCategory ?? "").uppercased()
        switch raw {
        case "PHARMACY":
            return ("cross.case.fill", Color.kilalaGreen.opacity(0.12), .kilalaGreen)
        case "RESTAURANT":
            return ("fork.knife", Color.kilalaGreen.opacity(0.12), .kilalaGreen)
        case "GROCERY":
            return ("cart.fill", Color.kilalaGreen.opacity(0.12), .kilalaGreen)
        case "TRANSPORT":
            return ("bus.fill", Color.kilalaGreen.opacity(0.12), .kilalaGreen)
        case "MEDICAL":
            return ("stethoscope", Color.kilalaGreen.opacity(0.12), .kilalaGreen)
        case "ENTERTAINMENT":
            return ("ticket.fill", Color.kilalaGreen.opacity(0.12), .kilalaGreen)
        default:
            return ("building.2.fill", Color.kilalaMint, .kilalaInk)
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
                                icon: "checkmark.seal.fill",
                                label: "Verified",
                                foreground: .kilalaStateValid,
                                background: Color.kilalaStateValid.opacity(0.12),
                                cornerRadius: 8
                            )

                            Spacer()
                        }

                        // Merchant Identity
                        VStack(alignment: .leading, spacing: 4) {
                            Text("MERCHANT")
                                .font(.kilala(.caption, weight: .bold))
                                .tracking(0.8)
                                .foregroundColor(.kilalaInkSecondary)

                            Text(transaction.businessName)
                                .font(.kilala(size: 22, weight: .bold, relativeTo: .title2))
                                .foregroundColor(.kilalaInk)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        // Branch Identity
                        VStack(alignment: .leading, spacing: 4) {
                            Text("BRANCH")
                                .font(.kilala(.caption, weight: .bold))
                                .tracking(0.8)
                                .foregroundColor(.kilalaInkSecondary)

                            Text(branchDisplayText)
                                .font(.kilala(size: 18, weight: .bold, relativeTo: .title3))
                                .foregroundColor(.kilalaInk)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Divider()
                            .overlay(Color.kilalaMintBorder)

                        // Audit Metadata Rows
                        VStack(spacing: 12) {
                            HStack(alignment: .center) {
                                Text("Category")
                                    .font(.kilala(.subheadline))
                                    .foregroundColor(.kilalaInkSecondary)

                                Spacer()

                                KilalaStatusBadge(
                                    icon: categoryBadge.icon,
                                    label: transaction.formattedCategory,
                                    foreground: categoryBadge.foreground,
                                    background: categoryBadge.fill,
                                    cornerRadius: 8
                                )
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
                                Text("Net Total")
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

private struct CardholderTransactionDateRangeSheet: View {
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
