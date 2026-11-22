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
    @State private var selectedDates: [Date] = []
    @State private var isCalendarPresented: Bool = false
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil

    private var calendar: Calendar {
        Calendar.current
    }

    /// Selected calendar days normalized to start-of-day and sorted chronologically (0, 1, or 2 dates).
    private var selectedDays: [Date] {
        selectedDates
            .map { calendar.startOfDay(for: $0) }
            .sorted()
    }

    private var filteredTransactions: [CardholderTransactionHistoryItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let activeDays = selectedDays

        return transactions.filter { item in
            // 1. Merchant search filter
            let matchesMerchant: Bool
            if query.isEmpty {
                matchesMerchant = true
            } else {
                matchesMerchant = item.businessName.localizedCaseInsensitiveContains(query) ||
                    (item.branchName?.localizedCaseInsensitiveContains(query) ?? false)
            }

            guard matchesMerchant else { return false }

            // 2. Date filter logic (0, 1, or 2 dates selected)
            guard !activeDays.isEmpty else {
                return true
            }

            guard let txDate = CardholderTransactionDateFormatting.parse(item.createdAt) else {
                return false
            }

            let txDay = calendar.startOfDay(for: txDate)
            if activeDays.count == 1 {
                return calendar.isDate(txDay, inSameDayAs: activeDays[0])
            } else {
                let startDay = activeDays[0]
                let endDay = activeDays[activeDays.count - 1]
                return txDay >= startDay && txDay <= endDay
            }
        }
    }

    private struct DateTransactionSection: Identifiable {
        let dayStart: Date
        let title: String
        let items: [CardholderTransactionHistoryItem]

        var id: Date { dayStart }
    }

    /// Groups filtered transactions by calendar date, sorted newest date first.
    private var groupedTransactionSections: [DateTransactionSection] {
        var buckets: [Date: [CardholderTransactionHistoryItem]] = [:]

        for item in filteredTransactions {
            let parsedDate = CardholderTransactionDateFormatting.parse(item.createdAt) ?? .distantPast
            let dayStart = calendar.startOfDay(for: parsedDate)
            buckets[dayStart, default: []].append(item)
        }

        return buckets.keys
            .sorted(by: >)
            .map { dayStart in
                let sortedItems = (buckets[dayStart] ?? []).sorted { lhs, rhs in
                    let lhsDate = CardholderTransactionDateFormatting.parse(lhs.createdAt) ?? .distantPast
                    let rhsDate = CardholderTransactionDateFormatting.parse(rhs.createdAt) ?? .distantPast
                    return lhsDate > rhsDate
                }
                return DateTransactionSection(
                    dayStart: dayStart,
                    title: CardholderTransactionDateFormatting.formatSectionDate(dayStart),
                    items: sortedItems
                )
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

                    // Single-line Search & Calendar Filter Bar
                    topFilterBar

                    if isCalendarPresented {
                        calendarPickerCard
                    }

                    if let errorMessage = errorMessage {
                        errorBanner(message: errorMessage)
                    }

                    if isLoading && transactions.isEmpty {
                        loadingCard
                    } else if filteredTransactions.isEmpty {
                        emptyStateCard
                    } else {
                        dateSeparatedTransactionsList
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
    }

    // MARK: - Top Search & Calendar Filter Bar (Single Line Only)

    private var topFilterBar: some View {
        HStack(spacing: 10) {
            // Merchant Search Bar
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
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 46)
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.kilalaMintBorder, lineWidth: 1)
            )

            // Calendar Filter Icon Button (No inline date text inputs)
            let hasActiveDateFilter = !selectedDays.isEmpty
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isCalendarPresented.toggle()
                }
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "calendar")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(
                            (isCalendarPresented || hasActiveDateFilter) ? .white : .kilalaInk
                        )
                        .frame(width: 46, height: 46)
                        .background(
                            (isCalendarPresented || hasActiveDateFilter)
                                ? Color.kilalaGreen
                                : Color.white
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(
                                    (isCalendarPresented || hasActiveDateFilter)
                                        ? Color.kilalaGreen
                                        : Color.kilalaMintBorder,
                                    lineWidth: 1
                                )
                        )

                    if hasActiveDateFilter {
                        Text("\(selectedDays.count)")
                            .font(.kilala(size: 11, weight: .bold, relativeTo: .caption2))
                            .foregroundColor(.kilalaInk)
                            .frame(width: 18, height: 18)
                            .background(Color.kilalaSunrise)
                            .clipShape(Circle())
                            .offset(x: 4, y: -4)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Filter by date")
        }
    }

    // MARK: - Expandable Calendar Picker Card

    private var dateFilterSummaryText: String {
        let days = selectedDays
        switch days.count {
        case 0:
            return "Select 1 date or 2 dates for a range"
        case 1:
            return CardholderTransactionDateFormatting.formatSectionDate(days[0])
        default:
            let start = CardholderTransactionDateFormatting.formatShortDate(days[0])
            let end = CardholderTransactionDateFormatting.formatShortDate(days[days.count - 1])
            return "\(start) – \(end)"
        }
    }

    private var calendarPickerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Text(dateFilterSummaryText)
                    .font(.kilala(.footnote, weight: .semibold))
                    .foregroundColor(.kilalaInkSecondary)
                    .lineLimit(1)

                Spacer()

                if !selectedDates.isEmpty {
                    Button("Clear") {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedDates.removeAll()
                        }
                    }
                    .font(.kilala(.footnote, weight: .bold))
                    .foregroundColor(.kilalaGreen)
                }
            }

            Divider()
                .overlay(Color.kilalaMintBorder)

            CardholderRangeCalendarView(selectedDates: $selectedDates)
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.kilalaMintBorder, lineWidth: 1)
        )
    }

    // MARK: - Date-Separated Transaction List

    private var dateSeparatedTransactionsList: some View {
        LazyVStack(alignment: .leading, spacing: 16) {
            ForEach(groupedTransactionSections) { section in
                VStack(alignment: .leading, spacing: 8) {
                    Text(section.title)
                        .font(.kilala(.subheadline, weight: .bold))
                        .foregroundColor(.kilalaInkSecondary)
                        .padding(.horizontal, 4)

                    VStack(spacing: 0) {
                        ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                            CardholderTransactionHistoryRow(item: item)

                            if index < section.items.count - 1 {
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
            }
        }
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
        let isFiltering = !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !selectedDays.isEmpty
        return VStack(spacing: 8) {
            Image(systemName: isFiltering ? "magnifyingglass" : "receipt")
                .font(.system(size: 28))
                .foregroundColor(.kilalaInkMuted)
                .accessibilityHidden(true)

            Text(isFiltering ? "No matching transactions" : "No Transactions Yet")
                .font(.kilala(.headline, weight: .bold))
                .foregroundColor(.kilalaInk)

            Text(
                isFiltering
                    ? "Try a different merchant name or adjust your selected date filter."
                    : "Your 20% statutory discount transactions will appear here."
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
            let activeToken = token.isEmpty ? (APIService.shared.authToken ?? "") : token
            transactions = try await APIService.shared.fetchCardholderTransactions(token: activeToken)
            isLoading = false
        } catch is CancellationError {
            // Task cancelled
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

// MARK: - Cardholder Transaction Row

struct CardholderTransactionHistoryRow: View {
    let item: CardholderTransactionHistoryItem

    private var formattedTimestamp: String {
        CardholderTransactionDateFormatting.formatRowTimestamp(item.createdAt)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Left Side: Merchant name in bold, with "Month Day, Time" directly below it
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

            // Right Side: Discounted total in bold ("₱XX.XX"), with "From ₱XX.XX" directly below it
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
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .frame(minHeight: 60)
        .contentShape(Rectangle())
    }
}

// MARK: - Cardholder Transaction Date Formatting

enum CardholderTransactionDateFormatting {
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

    private static let rowFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.amSymbol = "AM"
        formatter.pmSymbol = "PM"
        formatter.dateFormat = "MMM d, hh:mm a"
        return formatter
    }()

    private static let sectionDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter
    }()

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()

    static func parse(_ isoString: String) -> Date? {
        isoFractional.date(from: isoString) ?? isoStandard.date(from: isoString)
    }

    /// Formats row subtitle as "Month Day, Time" where Month is max 3 chars and Time is HH:MM AM/PM (e.g., "Nov 23, 02:30 PM").
    static func formatRowTimestamp(_ isoString: String) -> String {
        guard let date = parse(isoString) else { return isoString }
        return rowFormatter.string(from: date)
    }

    static func formatSectionDate(_ date: Date) -> String {
        sectionDateFormatter.string(from: date)
    }

    static func formatShortDate(_ date: Date) -> String {
        shortDateFormatter.string(from: date)
    }
}

// MARK: - Range-Highlighting Calendar Picker

struct CardholderRangeCalendarView: View {
    @Binding var selectedDates: [Date]

    @State private var displayedMonth: Date = {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: Date())
        return cal.date(from: comps) ?? Date()
    }()

    private var calendar: Calendar {
        Calendar.current
    }

    private let weekdayHeaders = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    private static let monthTitleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    private var sortedSelectedDays: [Date] {
        selectedDates
            .map { calendar.startOfDay(for: $0) }
            .sorted()
    }

    private struct CalendarCellItem: Identifiable {
        let id: String
        let date: Date?
        let dayNumber: Int
        let columnIndex: Int
        let isFirstDayOfMonth: Bool
        let isLastDayOfMonth: Bool
    }

    private var monthCells: [CalendarCellItem] {
        guard let monthStart = calendar.date(
            from: calendar.dateComponents([.year, .month], from: displayedMonth)
        ),
        let dayRange = calendar.range(of: .day, in: .month, for: monthStart) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: monthStart) // 1 = Sunday ... 7 = Saturday
        let leadingEmptyCount = max(0, firstWeekday - 1)
        let totalDays = dayRange.count

        var items: [CalendarCellItem] = []

        for emptyIndex in 0..<leadingEmptyCount {
            items.append(
                CalendarCellItem(
                    id: "empty-\(emptyIndex)",
                    date: nil,
                    dayNumber: 0,
                    columnIndex: emptyIndex % 7,
                    isFirstDayOfMonth: false,
                    isLastDayOfMonth: false
                )
            )
        }

        for day in 1...totalDays {
            let offsetIndex = leadingEmptyCount + (day - 1)
            let dayDate = calendar.date(byAdding: .day, value: day - 1, to: monthStart).map {
                calendar.startOfDay(for: $0)
            }
            items.append(
                CalendarCellItem(
                    id: "day-\(day)",
                    date: dayDate,
                    dayNumber: day,
                    columnIndex: offsetIndex % 7,
                    isFirstDayOfMonth: day == 1,
                    isLastDayOfMonth: day == totalDays
                )
            )
        }

        return items
    }

    var body: some View {
        VStack(spacing: 12) {
            // Month Header & Navigation Chevrons
            HStack(alignment: .center) {
                Text(Self.monthTitleFormatter.string(from: displayedMonth))
                    .font(.kilala(.callout, weight: .bold))
                    .foregroundColor(.kilalaInk)

                Spacer()

                HStack(spacing: 6) {
                    Button {
                        shiftMonth(by: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.kilalaGreen)
                            .frame(width: 32, height: 32)
                            .background(Color.kilalaPaper)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Previous month")

                    Button {
                        shiftMonth(by: 1)
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.kilalaGreen)
                            .frame(width: 32, height: 32)
                            .background(Color.kilalaPaper)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Next month")
                }
            }

            // Weekday Header Labels
            LazyVGrid(columns: gridColumns, spacing: 0) {
                ForEach(weekdayHeaders, id: \.self) { label in
                    Text(label)
                        .font(.kilala(size: 11, weight: .bold, relativeTo: .caption2))
                        .foregroundColor(.kilalaInkMuted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 24)
                }
            }

            // Days Grid with Continuous Range Highlighting
            LazyVGrid(columns: gridColumns, spacing: 6) {
                ForEach(monthCells) { cell in
                    if let dayDate = cell.date {
                        dayCellView(for: cell, dayDate: dayDate)
                    } else {
                        Color.clear
                            .frame(height: 38)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func dayCellView(for cell: CalendarCellItem, dayDate: Date) -> some View {
        let sorted = sortedSelectedDays
        let isStart = !sorted.isEmpty && calendar.isDate(dayDate, inSameDayAs: sorted[0])
        let isEnd = sorted.count >= 2 && calendar.isDate(dayDate, inSameDayAs: sorted[sorted.count - 1])
        let isEndpoint = isStart || isEnd
        let hasRange = sorted.count >= 2 && !calendar.isDate(sorted[0], inSameDayAs: sorted[sorted.count - 1])
        let isInRange = hasRange && dayDate > sorted[0] && dayDate < sorted[sorted.count - 1]
        let isToday = calendar.isDateInToday(dayDate)

        let roundLeftCap = cell.columnIndex == 0 || cell.isFirstDayOfMonth
        let roundRightCap = cell.columnIndex == 6 || cell.isLastDayOfMonth
        let rangeHighlightColor = Color.kilalaGreen.opacity(0.16)

        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                handleTap(on: dayDate)
            }
        } label: {
            ZStack {
                // Continuous Range Highlight Strip (when 2 dates are picked)
                if hasRange {
                    if isInRange {
                        UnevenRoundedRectangle(
                            topLeadingRadius: roundLeftCap ? 18 : 0,
                            bottomLeadingRadius: roundLeftCap ? 18 : 0,
                            bottomTrailingRadius: roundRightCap ? 18 : 0,
                            topTrailingRadius: roundRightCap ? 18 : 0,
                            style: .continuous
                        )
                        .fill(rangeHighlightColor)
                        .frame(height: 36)
                    } else if isStart && !roundRightCap {
                        HStack(spacing: 0) {
                            Color.clear
                            Rectangle()
                                .fill(rangeHighlightColor)
                        }
                        .frame(height: 36)
                    } else if isEnd && !roundLeftCap {
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(rangeHighlightColor)
                            Color.clear
                        }
                        .frame(height: 36)
                    }
                }

                // Endpoint Circle or Today Ring
                if isEndpoint {
                    Circle()
                        .fill(Color.kilalaGreen)
                        .frame(width: 36, height: 36)
                } else if isToday && !isInRange {
                    Circle()
                        .stroke(Color.kilalaGreen, lineWidth: 1.2)
                        .frame(width: 36, height: 36)
                }

                // Day Number Label
                Text("\(cell.dayNumber)")
                    .font(
                        .kilala(
                            .subheadline,
                            weight: (isEndpoint || isInRange || isToday) ? .bold : .medium
                        )
                    )
                    .foregroundColor(
                        isEndpoint
                            ? .white
                            : (isInRange || isToday ? .kilalaGreen : .kilalaInk)
                    )
            }
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func shiftMonth(by offset: Int) {
        if let nextMonth = calendar.date(byAdding: .month, value: offset, to: displayedMonth) {
            withAnimation(.easeInOut(duration: 0.18)) {
                displayedMonth = nextMonth
            }
        }
    }

    private func handleTap(on dayDate: Date) {
        let normalized = calendar.startOfDay(for: dayDate)
        let current = sortedSelectedDays

        switch current.count {
        case 0:
            selectedDates = [normalized]
        case 1:
            if calendar.isDate(normalized, inSameDayAs: current[0]) {
                selectedDates = []
            } else {
                selectedDates = [current[0], normalized].sorted()
            }
        default:
            if calendar.isDate(normalized, inSameDayAs: current[0]) {
                selectedDates = [current[current.count - 1]]
            } else if calendar.isDate(normalized, inSameDayAs: current[current.count - 1]) {
                selectedDates = [current[0]]
            } else {
                selectedDates = [normalized]
            }
        }
    }
}
