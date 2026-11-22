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
                return "list.bullet.rectangle"
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
        ZStack {
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
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                                selectedTab = .transactions
                            }
                        },
                        onRefresh: {
                            await loadDashboardMetrics(for: selectedTimeframe)
                        },
                        onLogout: onLogout
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

            VStack {
                Spacer()

                BusinessSplitBottomBar(
                    selectedTab: $selectedTab,
                    onScanQR: {
                        isScannerPresented = true
                    }
                )
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
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
            NavigationStack {
                QRScannerView(
                    token: activeToken,
                    onLogout: onLogout,
                    isEmbeddedInDrawer: true,
                    isScannerVisible: isScannerPresented
                ) {
                    Task {
                        await loadDashboardMetrics(for: selectedTimeframe)
                    }
                }
                .navigationTitle("Scan QR")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Close") {
                            isScannerPresented = false
                        }
                        .font(.kilala(.subheadline, weight: .semibold))
                        .foregroundColor(.kilalaInk)
                    }
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
    var onLogout: (() -> Void)? = nil

    @State private var selectedTransaction: TransactionHistoryItem? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.kilalaPaper
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if let errorMessage = errorMessage {
                            errorBanner(message: errorMessage)
                        }

                        // Performance Overview Card (matches Digital ID outer card hierarchy)
                        analyticsOverviewCard

                        // Recent Activity Card
                        recentActivityCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 108)
                }
                .refreshable {
                    await onRefresh()
                }
                .safeAreaInset(edge: .top, spacing: 0) {
                    BusinessPortalHeader(title: "Dashboard", onLogout: onLogout)
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

    // MARK: - Analytics Overview Card

    private var analyticsOverviewCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Card Header: Business Identity & Accreditation Pill
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text((businessProfile?.lguName ?? "Performance Overview").uppercased())
                        .font(.kilala(.caption, weight: .bold))
                        .tracking(0.8)
                        .foregroundColor(.kilalaInkSecondary)

                    Text(businessProfile?.businessName ?? "Business Analytics")
                        .font(.kilala(.title3, weight: .bold))
                        .foregroundColor(.kilalaInk)
                }

                Spacer(minLength: 8)

                accreditationBadge
            }

            // Timeframe Segmented Picker
            Picker("Timeframe", selection: $selectedTimeframe) {
                Text("24 Hours").tag(DashboardTimeframe.past24Hours)
                Text("Past Week").tag(DashboardTimeframe.pastWeek)
                Text("Past Month").tag(DashboardTimeframe.pastMonth)
            }
            .pickerStyle(.segmented)

            // Elevated White Inner Metric Sub-Cards
            VStack(spacing: 14) {
                MetricSubCard(
                    label: "TOTAL DISCOUNTED AMOUNT",
                    value: String(format: "₱%.2f", totalDiscountedAmount),
                    subtitle: "Net revenue collected after 20% discount (\(selectedTimeframe.title.lowercased()))",
                    badgeText: "\(transactionCount) Verified",
                    badgeFill: Color.kilalaStateValid.opacity(0.15),
                    badgeForeground: .kilalaStateValid,
                    isLoading: isLoading
                )

                MetricSubCard(
                    label: "TOTAL DISCOUNTED SALES",
                    value: String(format: "₱%.2f", totalDiscountedSales),
                    subtitle: "20% statutory discount granted across verified scans",
                    badgeText: String(format: "Gross ₱%.2f", totalOriginalAmount),
                    badgeFill: Color.kilalaMint,
                    badgeForeground: .kilalaInkSecondary,
                    isLoading: isLoading
                )
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

    private var accreditationBadge: some View {
        let isAccredited = businessProfile?.isAccredited ?? true
        return Text(isAccredited ? "Accredited" : "Inactive")
            .font(.kilala(.caption, weight: .bold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                isAccredited
                    ? Color.kilalaStateValid.opacity(0.15)
                    : Color.kilalaStateInvalid.opacity(0.15)
            )
            .foregroundColor(isAccredited ? .kilalaStateValid : .kilalaStateInvalid)
            .clipShape(Capsule())
    }

    // MARK: - Recent Activity Card

    private var recentActivityCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                Text("RECENT ACTIVITY")
                    .font(.kilala(.caption, weight: .bold))
                    .tracking(0.8)
                    .foregroundColor(.kilalaInkSecondary)

                Spacer()

                Button(action: onSeeAllTransactions) {
                    HStack(spacing: 4) {
                        Text("See All")
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.bold))
                    }
                    .font(.kilala(.caption, weight: .bold))
                    .foregroundColor(.kilalaGreen)
                }
            }

            if isLoading && recentTransactions.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(.kilalaGreen)
                        .padding(.vertical, 24)
                    Spacer()
                }
            } else if recentTransactions.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "receipt")
                        .font(.title2)
                        .foregroundColor(.kilalaGreen.opacity(0.7))

                    Text("No transactions in the \(selectedTimeframe.title.lowercased()).")
                        .font(.kilala(.subheadline, weight: .bold))
                        .foregroundColor(.kilalaInk)
                        .multilineTextAlignment(.center)

                    Text("Tap Scan QR in the bottom right to verify a Kilala ID.")
                        .font(.kilala(.caption))
                        .foregroundColor(.kilalaInkSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .padding(.horizontal, 16)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.kilalaMintBorder, lineWidth: 1)
                )
                .shadow(color: Color.kilalaInk.opacity(0.05), radius: 8, x: 0, y: 4)
            } else {
                VStack(spacing: 10) {
                    ForEach(recentTransactions.prefix(5)) { item in
                        Button {
                            selectedTransaction = item
                        } label: {
                            TransactionHistoryRow(item: item)
                        }
                        .buttonStyle(.plain)
                    }
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

    // MARK: - Error Banner

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
                    await onRefresh()
                }
            }
            .font(.kilala(.caption, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.kilalaGreen)
            .clipShape(Capsule())
        }
        .padding(14)
        .background(Color.kilalaMint)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.kilalaStateInvalid.opacity(0.30), lineWidth: 1)
        )
    }
}

// MARK: - Elevated White Metric Sub-Card

private struct MetricSubCard: View {
    let label: String
    let value: String
    let subtitle: String
    let badgeText: String
    let badgeFill: Color
    let badgeForeground: Color
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Text(label)
                    .font(.kilala(.caption, weight: .bold))
                    .tracking(0.8)
                    .foregroundColor(.kilalaInkSecondary)

                Spacer(minLength: 4)

                Text(badgeText)
                    .font(.kilala(.caption, weight: .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(badgeFill)
                    .foregroundColor(badgeForeground)
                    .clipShape(Capsule())
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(value)
                    .font(.kilala(size: 30, weight: .bold, relativeTo: .largeTitle))
                    .foregroundColor(.kilalaInk)
                    .contentTransition(.numericText())

                if isLoading {
                    ProgressView()
                        .tint(.kilalaGreen)
                        .scaleEffect(0.8)
                }
            }

            Text(subtitle)
                .font(.kilala(.footnote))
                .foregroundColor(.kilalaInkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.kilalaMintBorder, lineWidth: 1)
        )
        .shadow(color: Color.kilalaInk.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Split Floating Bottom Bar

private struct BusinessSplitBottomBar: View {
    @Binding var selectedTab: BusinessDashboardView.Tab
    let onScanQR: () -> Void

    @Namespace private var activeTabNamespace

    private let barHeight: CGFloat = 64

    var body: some View {
        HStack(spacing: 12) {
            // Left Component: 3-Tab Floating Navigation Pill
            HStack(spacing: 4) {
                ForEach(BusinessDashboardView.Tab.allCases, id: \.self) { tab in
                    let isSelected = selectedTab == tab

                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                            selectedTab = tab
                        }
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: tab.iconName(isSelected: isSelected))
                                .font(.system(size: 19, weight: isSelected ? .semibold : .regular))

                            Text(tab.title)
                                .font(.kilala(size: 10, weight: isSelected ? .bold : .medium, relativeTo: .caption2))
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                        .foregroundColor(isSelected ? .kilalaInk : .kilalaInkSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(Color.kilalaMint)
                                    .matchedGeometryEffect(id: "activeTabHighlight", in: activeTabNamespace)
                            }
                        }
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tab.title)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(5)
            .frame(maxWidth: .infinity)
            .frame(height: barHeight)
            .background(Color.white)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.kilalaMintBorder, lineWidth: 1)
            )
            .shadow(color: Color.kilalaInk.opacity(0.10), radius: 14, x: 0, y: 6)

            // Right Component: Detached Circular Scan QR Button
            Button(action: onScanQR) {
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: barHeight, height: barHeight)
                    .background(Color.kilalaGreen)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.kilalaSunrise.opacity(0.45), lineWidth: 1.5)
                    )
                    .shadow(color: Color.kilalaGreen.opacity(0.30), radius: 14, x: 0, y: 6)
            }
            .buttonStyle(TactileScaleButtonStyle())
            .accessibilityLabel("Scan QR")
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 8)
    }
}

private struct TactileScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
