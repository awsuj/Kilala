//
//  BusinessDashboardView.swift
//  Kilala
//
//  Created by Joshua Calibo on 11/07/26.
//

import SwiftUI

struct BusinessDashboardView: View {
    var token: String = APIService.shared.authToken ?? ""
    var onLogout: (() -> Void)? = nil

    enum Tab: Hashable {
        case home
        case transactions
        case profile
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
        TabView(selection: $selectedTab) {
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
                onScanQR: {
                    isScannerPresented = true
                },
                onSeeAllTransactions: {
                    selectedTab = .transactions
                },
                onRefresh: {
                    await loadDashboardMetrics(for: selectedTimeframe)
                },
                onLogout: onLogout
            )
            .tabItem {
                Label("Home", systemImage: selectedTab == .home ? "house.fill" : "house")
            }
            .tag(Tab.home)

            NavigationStack {
                BusinessTransactionHistoryView()
            }
            .tabItem {
                Label("Transactions", systemImage: "list.bullet.rectangle")
            }
            .tag(Tab.transactions)

            NavigationStack {
                BusinessProfileView(profile: businessProfile) { updated in
                    businessProfile = updated
                }
            }
            .tabItem {
                Label("Profile", systemImage: selectedTab == .profile ? "person.fill" : "person")
            }
            .tag(Tab.profile)
        }
        .tint(.black)
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
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                    }
                }
            }
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
    let onScanQR: () -> Void
    let onSeeAllTransactions: () -> Void
    let onRefresh: () async -> Void
    var onLogout: (() -> Void)? = nil

    private static let darkGreenText = Color(red: 0.09, green: 0.48, blue: 0.22)
    private static let darkRedText = Color(red: 0.72, green: 0.14, blue: 0.14)

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white
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
                    .padding(.bottom, 32)
                }
                .refreshable {
                    await onRefresh()
                }
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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

                if let onLogout = onLogout {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Logout", action: onLogout)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                    }
                }
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
                        .font(.caption)
                        .fontWeight(.bold)
                        .tracking(0.8)
                        .foregroundColor(.gray)

                    Text(businessProfile?.businessName ?? "Business Analytics")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
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
                    badgeFill: Color.green.opacity(0.15),
                    badgeForeground: Self.darkGreenText,
                    isLoading: isLoading
                )

                MetricSubCard(
                    label: "TOTAL DISCOUNTED SALES",
                    value: String(format: "₱%.2f", totalDiscountedSales),
                    subtitle: "20% statutory discount granted across verified scans",
                    badgeText: String(format: "Gross ₱%.2f", totalOriginalAmount),
                    badgeFill: Color(white: 0.93),
                    badgeForeground: Color(white: 0.30),
                    isLoading: isLoading
                )
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

    private var accreditationBadge: some View {
        let isAccredited = businessProfile?.isAccredited ?? true
        return Text(isAccredited ? "Accredited" : "Inactive")
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                isAccredited
                    ? Color.green.opacity(0.15)
                    : Color.red.opacity(0.15)
            )
            .foregroundColor(isAccredited ? Self.darkGreenText : Self.darkRedText)
            .clipShape(Capsule())
    }

    // MARK: - Recent Activity Card

    private var recentActivityCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                Text("RECENT ACTIVITY")
                    .font(.caption)
                    .fontWeight(.bold)
                    .tracking(0.8)
                    .foregroundColor(.gray)

                Spacer()

                Button(action: onSeeAllTransactions) {
                    HStack(spacing: 4) {
                        Text("See All")
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.bold))
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Color(white: 0.25))
                }
            }

            if isLoading && recentTransactions.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding(.vertical, 24)
                    Spacer()
                }
            } else if recentTransactions.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "receipt")
                        .font(.title2)
                        .foregroundColor(.gray)

                    Text("No transactions in the \(selectedTimeframe.title.lowercased()).")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)

                    Text("Tap Scan QR in the top left to verify a Kilala ID.")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .padding(.horizontal, 16)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
            } else {
                VStack(spacing: 10) {
                    ForEach(recentTransactions.prefix(5)) { item in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.cardholderName)
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.black)

                                Text(formatTransactionDate(item.createdAt))
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
                        }
                        .padding(14)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                    }
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

    // MARK: - Error Banner

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
                    await onRefresh()
                }
            }
            .font(.caption.weight(.bold))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(white: 0.25))
            .clipShape(Capsule())
        }
        .padding(14)
        .background(Color(white: 0.96))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.gray.opacity(0.25), lineWidth: 1)
        )
    }

    private func formatTransactionDate(_ isoString: String) -> String {
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
                    .font(.caption)
                    .fontWeight(.bold)
                    .tracking(0.8)
                    .foregroundColor(.gray)

                Spacer(minLength: 4)

                Text(badgeText)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(badgeFill)
                    .foregroundColor(badgeForeground)
                    .clipShape(Capsule())
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(value)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.black)
                    .contentTransition(.numericText())

                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            Text(subtitle)
                .font(.footnote)
                .foregroundColor(Color(white: 0.35))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.gray.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}
