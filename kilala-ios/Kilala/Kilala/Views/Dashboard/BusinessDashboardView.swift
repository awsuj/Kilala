//
//  BusinessDashboardView.swift
//  Kilala
//
//  Created by Joshua Calibo on 11/07/26.
//

import SwiftUI

struct BusinessDashboardView: View {
    var token: String = APIService.shared.authToken ?? ""
    var userEmail: String? = APIService.shared.currentUserEmail
    var onLogout: (() -> Void)? = nil

    enum Tab: Hashable, CaseIterable {
        case home
        case transactions
        case profile

        var title: String {
            switch self {
            case .home:
                return "Home"
            case .transactions:
                return "Transactions"
            case .profile:
                return "Profile"
            }
        }

        func iconName(isSelected: Bool) -> String {
            switch self {
            case .home:
                return isSelected ? "house.fill" : "house"
            case .transactions:
                return isSelected ? "list.bullet.rectangle.fill" : "list.bullet.rectangle"
            case .profile:
                return isSelected ? "person.fill" : "person"
            }
        }
    }

    // MARK: - Navigation & Modal State
    @State private var selectedTab: Tab = .home
    @State private var isScannerPresented: Bool = false

    // MARK: - Dashboard Analytics State
    @State private var businessProfile: BusinessProfile? = APIService.shared.currentBusinessProfile
    @State private var selectedTimeframe: DashboardTimeframe = .past24Hours
    @State private var totalDiscountedAmount: Double = 0.0
    @State private var totalDiscountedSales: Double = 0.0
    @State private var totalOriginalAmount: Double = 0.0
    @State private var transactionCount: Int = 0
    @State private var recentTransactions: [TransactionHistoryItem] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil

    private var activeToken: String {
        token.isEmpty ? (APIService.shared.authToken ?? "") : token
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    switch selectedTab {
                    case .home:
                        BusinessHomeView(
                            businessProfile: businessProfile,
                            selectedTimeframe: $selectedTimeframe,
                            totalDiscountedAmount: totalDiscountedAmount,
                            totalDiscountedSales: totalDiscountedSales,
                            totalOriginalAmount: totalOriginalAmount,
                            transactionCount: transactionCount,
                            recentTransactions: recentTransactions,
                            isLoading: isLoading,
                            errorMessage: errorMessage,
                            onSeeAllTransactions: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedTab = .transactions
                                }
                            },
                            onRefresh: {
                                await loadDashboardMetrics(for: selectedTimeframe)
                            }
                        )

                    case .transactions:
                        NavigationStack {
                            BusinessTransactionHistoryView(
                                onLogout: onLogout,
                                showBrandLogo: true
                            )
                        }

                    case .profile:
                        NavigationStack {
                            BusinessProfileView(
                                token: activeToken,
                                profile: businessProfile,
                                userEmail: userEmail,
                                onLogout: onLogout
                            ) { updated in
                                businessProfile = updated
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Detached 56x56 Floating Scan QR Button (16pt above tab bar, 16pt trailing)
                Button {
                    isScannerPresented = true
                } label: {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.kilalaGreen)
                        .clipShape(Circle())
                        .shadow(color: Color.kilalaInk.opacity(0.18), radius: 10, x: 0, y: 4)
                }
                .buttonStyle(TactileScaleButtonStyle())
                .accessibilityLabel("Scan QR")
                .padding(.trailing, 16)
                .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Flat, Compact Bottom Tab Bar anchored to bottom safe area
            BusinessFlatTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .tint(.kilalaGreen)
        .onAppear {
            if !token.isEmpty {
                APIService.shared.authToken = token
            }
        }
        .task {
            if let fetchedProfile = try? await APIService.shared.fetchBusinessProfile() {
                businessProfile = fetchedProfile
            }
        }
        .task(id: selectedTimeframe) {
            await loadDashboardMetrics(for: selectedTimeframe)
        }
        .fullScreenCover(isPresented: $isScannerPresented) {
            QRScannerView(
                token: activeToken,
                onLogout: onLogout,
                isEmbeddedInDrawer: true,
                isScannerVisible: isScannerPresented,
                onClose: {
                    isScannerPresented = false
                }
            ) {
                Task {
                    await loadDashboardMetrics(for: selectedTimeframe)
                }
            }
            .tint(.kilalaGreen)
        }
    }

    // MARK: - Helpers

    private func loadDashboardMetrics(for timeframe: DashboardTimeframe) async {
        if !token.isEmpty {
            APIService.shared.authToken = token
        }
        isLoading = true
        errorMessage = nil

        do {
            let summary = try await APIService.shared.fetchBusinessDashboardSummary(range: timeframe.rawValue)
            totalDiscountedAmount = summary.totalDiscountedAmount
            totalDiscountedSales = summary.totalDiscountedSales
            totalOriginalAmount = summary.totalOriginalAmount ?? (summary.totalDiscountedAmount + summary.totalDiscountedSales)
            transactionCount = summary.transactionCount ?? (summary.transactions?.count ?? 0)
            recentTransactions = summary.transactions ?? []
            isLoading = false
        } catch is CancellationError {
            // Task cancelled by rapid timeframe switch
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

// MARK: - Business Home Tab View

private struct BusinessHomeView: View {
    let businessProfile: BusinessProfile?
    @Binding var selectedTimeframe: DashboardTimeframe
    let totalDiscountedAmount: Double
    let totalDiscountedSales: Double
    let totalOriginalAmount: Double
    let transactionCount: Int
    let recentTransactions: [TransactionHistoryItem]
    let isLoading: Bool
    let errorMessage: String?
    let onSeeAllTransactions: () -> Void
    let onRefresh: () async -> Void

    @State private var selectedTransaction: TransactionHistoryItem? = nil

    private var merchantContextText: String {
        let name = businessProfile?.businessName.trimmingCharacters(in: .whitespacesAndNewlines)
        let lgu = businessProfile?.lguName?.trimmingCharacters(in: .whitespacesAndNewlines)

        switch (name?.isEmpty == false ? name : nil, lgu?.isEmpty == false ? lgu : nil) {
        case let (business?, municipality?):
            return "\(business) · \(municipality)"
        case let (business?, nil):
            return business
        case let (nil, municipality?):
            return municipality
        default:
            return "Merchant Account"
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.kilalaPaper
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        // Stacked Mobile Editorial Header + Contextual Merchant Line
                        VStack(alignment: .leading, spacing: 12) {
                            BusinessPortalHeader(title: "Dashboard")

                            merchantContextLine
                        }

                        // Compact 36pt Time-Period Selector
                        TimeframeSegmentedBar(
                            selectedTimeframe: $selectedTimeframe,
                            isLoading: isLoading
                        )

                        if let errorMessage = errorMessage {
                            errorBanner(message: errorMessage)
                        }

                        // Single Consolidated Financial Summary Card
                        financialSummaryCard

                        // Compact Recent Activity Section (Above the Fold)
                        recentActivitySection
                            .padding(.top, 8)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 96)
                }
                .refreshable {
                    await onRefresh()
                }
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $selectedTransaction) { item in
                TransactionDetailSheet(transaction: item)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Contextual Merchant Line (Inline, Not a Card)

    private var merchantContextLine: some View {
        let isAccredited = businessProfile?.isAccredited ?? true
        return HStack(alignment: .center, spacing: 8) {
            Text(merchantContextText)
                .font(.kilala(.subheadline, weight: .semibold))
                .foregroundColor(.kilalaInk)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 4)

            KilalaStatusBadge(
                icon: isAccredited ? "checkmark.circle.fill" : "xmark.circle.fill",
                label: isAccredited ? "Accredited" : "Inactive",
                foreground: isAccredited ? .kilalaStateValid : .kilalaStateInvalid,
                background: isAccredited
                    ? Color.kilalaStateValid.opacity(0.12)
                    : Color.kilalaStateInvalid.opacity(0.12),
                cornerRadius: 8
            )
        }
    }

    // MARK: - Consolidated Financial Summary Card

    private var financialSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top Label
            Text("DISCOUNTS GIVEN")
                .font(.kilala(.caption, weight: .bold))
                .tracking(0.8)
                .foregroundColor(.kilalaInkSecondary)

            // Hero Figure
            HStack(alignment: .center, spacing: 8) {
                Text(String(format: "₱%.2f", totalDiscountedSales))
                    .font(.kilala(size: 34, weight: .bold, relativeTo: .largeTitle))
                    .foregroundColor(.kilalaGreen)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                ProgressView()
                    .tint(.kilalaGreen)
                    .scaleEffect(0.8)
                    .opacity(isLoading ? 1 : 0)
                    .accessibilityHidden(!isLoading)
            }

            Divider()
                .overlay(Color.kilalaMintBorder)
                .padding(.vertical, 2)

            // 2-Column Secondary Breakdown
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Net Sales Collected")
                        .font(.kilala(.footnote, weight: .medium))
                        .foregroundColor(.kilalaInkSecondary)

                    Text(String(format: "₱%.2f", totalDiscountedAmount))
                        .font(.kilala(size: 18, weight: .semibold, relativeTo: .headline))
                        .foregroundColor(.kilalaInk)
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Rectangle()
                    .fill(Color.kilalaMintBorder)
                    .frame(width: 1, height: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Gross Sales")
                        .font(.kilala(.footnote, weight: .medium))
                        .foregroundColor(.kilalaInkSecondary)

                    Text(String(format: "₱%.2f", totalOriginalAmount))
                        .font(.kilala(size: 18, weight: .semibold, relativeTo: .headline))
                        .foregroundColor(.kilalaInk)
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
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
    }

    // MARK: - Recent Activity Section

    private var sortedRecentTransactions: [TransactionHistoryItem] {
        let sortedNewestFirst = recentTransactions.sorted { lhs, rhs in
            let leftDate = TransactionDateFormatting.parse(lhs.createdAt) ?? Date.distantPast
            let rightDate = TransactionDateFormatting.parse(rhs.createdAt) ?? Date.distantPast
            return leftDate > rightDate
        }
        return Array(sortedNewestFirst.prefix(5))
    }

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                Text("Recent Activity")
                    .font(.kilala(.headline, weight: .bold))
                    .foregroundColor(.kilalaInk)

                Spacer()

                Button(action: onSeeAllTransactions) {
                    HStack(spacing: 4) {
                        Text("See all")
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .semibold))
                            .accessibilityHidden(true)
                    }
                    .font(.kilala(.subheadline, weight: .bold))
                    .foregroundColor(.kilalaGreen)
                    .frame(minHeight: 32)
                }
            }

            if isLoading && recentTransactions.isEmpty {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.kilalaMint)
                        .frame(height: 1)

                    HStack(spacing: 12) {
                        ProgressView()
                            .tint(.kilalaGreen)
                        Text("Loading recent activity...")
                            .font(.kilala(.callout))
                            .foregroundColor(.kilalaInkSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                    .padding(.horizontal, 16)
                }
                .background(Color.kilalaPaper)
            } else if recentTransactions.isEmpty {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.kilalaMint)
                        .frame(height: 1)

                    VStack(spacing: 8) {
                        Image(systemName: "receipt")
                            .font(.system(size: 26))
                            .foregroundColor(.kilalaInkMuted)
                            .accessibilityHidden(true)

                        Text("No verified discounts in this period")
                            .font(.kilala(.callout, weight: .bold))
                            .foregroundColor(.kilalaInk)
                            .multilineTextAlignment(.center)

                        Text("Tap the Scan QR button to verify a Kilala Digital ID.")
                            .font(.kilala(.footnote))
                            .foregroundColor(.kilalaInkSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .padding(.horizontal, 16)
                }
                .background(Color.kilalaPaper)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(sortedRecentTransactions.enumerated()), id: \.element.id) { index, item in
                        Button {
                            selectedTransaction = item
                        } label: {
                            TransactionHistoryRow(
                                item: item,
                                showCardNumber: false,
                                showTimeOnly: false,
                                showDateAndTime: true,
                                horizontalPadding: 16
                            )
                        }
                        .buttonStyle(.plain)

                        if index < sortedRecentTransactions.count - 1 {
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
            }
        }
    }

    // MARK: - Error Banner

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
                    await onRefresh()
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
}

// MARK: - Compact 36pt Time-Period Selector

private struct TimeframeSegmentedBar: View {
    @Binding var selectedTimeframe: DashboardTimeframe
    let isLoading: Bool

    private func shortLabel(for timeframe: DashboardTimeframe) -> String {
        switch timeframe {
        case .past24Hours:
            return "24 Hours"
        case .pastWeek:
            return "7 Days"
        case .pastMonth:
            return "30 Days"
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(DashboardTimeframe.allCases) { timeframe in
                let isSelected = selectedTimeframe == timeframe

                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selectedTimeframe = timeframe
                    }
                } label: {
                    Text(shortLabel(for: timeframe))
                        .font(.kilala(.footnote, weight: isSelected ? .bold : .semibold))
                        .foregroundColor(isSelected ? .white : .kilalaInkSecondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(isSelected ? Color.kilalaGreen : Color.clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(3)
        .frame(height: 36)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.kilalaMintBorder, lineWidth: 1)
        )
    }
}

// MARK: - Flat, Compact Bottom Tab Bar

private struct BusinessFlatTabBar: View {
    @Binding var selectedTab: BusinessDashboardView.Tab

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.kilalaBorder)
                .frame(height: 1)

            HStack(spacing: 0) {
                ForEach(BusinessDashboardView.Tab.allCases, id: \.self) { tab in
                    let isSelected = selectedTab == tab

                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            selectedTab = tab
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: tab.iconName(isSelected: isSelected))
                                .font(.system(size: 20, weight: isSelected ? .semibold : .regular))

                            Text(tab.title)
                                .font(.kilala(size: 11, weight: isSelected ? .bold : .medium, relativeTo: .caption2))
                                .lineLimit(1)
                        }
                        .foregroundColor(isSelected ? .kilalaGreen : .kilalaInkSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tab.title)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 2)
        }
        .background(
            Color.white
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

private struct TactileScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
