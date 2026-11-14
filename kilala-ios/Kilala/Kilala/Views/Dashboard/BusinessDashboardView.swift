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
    
    // MARK: - Pull-to-Scan Drawer Gesture State
    @State private var scannerOffset: CGFloat = 0
    @State private var isScannerOpen: Bool = false
    
    private let handleTrayHeight: CGFloat = 82
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let drawerHeight = max(geometry.size.height - 24, 480)
                let closedTravelDistance = max(drawerHeight - handleTrayHeight, 320)
                let currentDrawerYOffset = closedTravelDistance + scannerOffset
                let openProgress = min(max(-scannerOffset / closedTravelDistance, 0), 1)
                
                ZStack(alignment: .bottom) {
                    // Base Layer: Business Analytical Dashboard
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // Header Subtitle & Timeframe Segmented Picker
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Performance Overview")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                Picker("Timeframe", selection: $selectedTimeframe) {
                                    Text("Past 24 Hours").tag(DashboardTimeframe.past24Hours)
                                    Text("Past Week").tag(DashboardTimeframe.pastWeek)
                                    Text("Past Month").tag(DashboardTimeframe.pastMonth)
                                }
                                .pickerStyle(.segmented)
                            }
                            
                            if let errorMessage = errorMessage {
                                HStack(spacing: 10) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text(errorMessage)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Button("Retry") {
                                        Task {
                                            await loadDashboardMetrics(for: selectedTimeframe)
                                        }
                                    }
                                    .font(.caption.weight(.semibold))
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color(.secondarySystemGroupedBackground))
                                )
                            }
                            
                            // Summary Cards (VStack, RoundedRectangle backgrounds, drop shadows)
                            VStack(spacing: 16) {
                                SummaryMetricCard(
                                    title: "Total Discounted Amount",
                                    subtitle: "Net revenue collected after 20% statutory discount (\(selectedTimeframe.title.lowercased()))",
                                    amount: totalDiscountedAmount,
                                    systemImage: "banknote.fill",
                                    accentColor: .green,
                                    badgeText: "\(transactionCount) \(transactionCount == 1 ? "tx" : "txs")",
                                    isLoading: isLoading
                                )
                                
                                SummaryMetricCard(
                                    title: "Total Discounted Sales",
                                    subtitle: "Total sales volume minus original amounts (20% discount granted)",
                                    amount: totalDiscountedSales,
                                    systemImage: "tag.fill",
                                    accentColor: .blue,
                                    badgeText: String(format: "Gross: ₱%.2f", totalOriginalAmount),
                                    isLoading: isLoading
                                )
                            }
                            
                            // Recent Transactions & Full History Link
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Recent Transactions")
                                        .font(.headline)
                                    Spacer()
                                    NavigationLink(destination: BusinessTransactionHistoryView()) {
                                        HStack(spacing: 4) {
                                            Text("See All")
                                            Image(systemName: "chevron.right")
                                                .font(.caption.weight(.semibold))
                                        }
                                        .font(.subheadline.weight(.semibold))
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
                                            .foregroundColor(.secondary)
                                        Text("No transactions recorded in the \(selectedTimeframe.title.lowercased()).")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .multilineTextAlignment(.center)
                                        Text("Pull up the scanner tray below to verify a Kilala ID.")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .multilineTextAlignment(.center)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 24)
                                    .padding(.horizontal, 16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(Color(.secondarySystemGroupedBackground))
                                            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                                    )
                                } else {
                                    VStack(spacing: 10) {
                                        ForEach(recentTransactions.prefix(5)) { item in
                                            HStack(spacing: 12) {
                                                ZStack {
                                                    Circle()
                                                        .fill(Color.green.opacity(0.14))
                                                        .frame(width: 40, height: 40)
                                                    Image(systemName: "checkmark.seal.fill")
                                                        .foregroundColor(.green)
                                                }
                                                
                                                VStack(alignment: .leading, spacing: 3) {
                                                    Text(item.cardholderName)
                                                        .font(.subheadline.weight(.semibold))
                                                        .foregroundColor(.primary)
                                                    Text(formatTransactionDate(item.createdAt))
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                                
                                                Spacer()
                                                
                                                VStack(alignment: .trailing, spacing: 3) {
                                                    Text(String(format: "₱%.2f", item.discountedAmount))
                                                        .font(.subheadline.weight(.bold))
                                                        .foregroundColor(.green)
                                                    Text(String(format: "Orig: ₱%.2f", item.originalAmount))
                                                        .font(.caption2)
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                            .padding(14)
                                            .background(
                                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                    .fill(Color(.secondarySystemGroupedBackground))
                                                    .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                                            )
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, handleTrayHeight + 36)
                    }
                    .background(Color(.systemGroupedBackground).ignoresSafeArea())
                    .refreshable {
                        await loadDashboardMetrics(for: selectedTimeframe)
                    }
                    
                    // Dimming Backdrop when Scanner Drawer is pulled out
                    if openProgress > 0.01 {
                        Color.black
                            .opacity(0.45 * openProgress)
                            .ignoresSafeArea()
                            .onTapGesture {
                                snapScannerDrawer(open: false, closedTravelDistance: closedTravelDistance)
                            }
                    }
                    
                    // Foreground Pocket / Tray Layer: Pull-to-Scan QRScannerView Drawer
                    VStack(spacing: 0) {
                        // Draggable Handle Header
                        VStack(spacing: 8) {
                            Capsule()
                                .fill(Color.white.opacity(0.45))
                                .frame(width: 44, height: 5)
                                .padding(.top, 10)
                            
                            HStack(spacing: 10) {
                                Image(systemName: "qrcode.viewfinder")
                                    .font(.title3.weight(.semibold))
                                    .foregroundColor(.green)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(isScannerOpen ? "QR Verification Scanner" : "Pull Up to Scan QR ID")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundColor(.white)
                                    
                                    Text(isScannerOpen ? "Drag handle down to return to dashboard" : "Swipe up or tap handle to open camera")
                                        .font(.caption2)
                                        .foregroundColor(.white.opacity(0.75))
                                }
                                
                                Spacer()
                                
                                Image(systemName: isScannerOpen ? "chevron.down.circle.fill" : "chevron.up.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 12)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: handleTrayHeight)
                        .background(
                            Color(red: 0.08, green: 0.11, blue: 0.16)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            snapScannerDrawer(open: !isScannerOpen, closedTravelDistance: closedTravelDistance)
                        }
                        .gesture(
                            DragGesture(minimumDistance: 4, coordinateSpace: .global)
                                .onChanged { value in
                                    let startingOffset: CGFloat = isScannerOpen ? -closedTravelDistance : 0
                                    let proposedOffset = startingOffset + value.translation.height
                                    scannerOffset = min(0, max(-closedTravelDistance, proposedOffset))
                                }
                                .onEnded { value in
                                    let dragThreshold = closedTravelDistance * 0.25
                                    let shouldOpen: Bool
                                    if isScannerOpen {
                                        shouldOpen = !(value.translation.height > dragThreshold || value.predictedEndTranslation.height > dragThreshold * 1.6)
                                    } else {
                                        shouldOpen = (value.translation.height < -dragThreshold || value.predictedEndTranslation.height < -dragThreshold * 1.6)
                                    }
                                    snapScannerDrawer(open: shouldOpen, closedTravelDistance: closedTravelDistance)
                                }
                        )
                        
                        // Embedded Camera Viewfinder
                        QRScannerView(
                            token: token.isEmpty ? (APIService.shared.authToken ?? "") : token,
                            onLogout: onLogout,
                            isEmbeddedInDrawer: true,
                            isScannerVisible: openProgress > 0.2
                        ) {
                            Task {
                                await loadDashboardMetrics(for: selectedTimeframe)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                    }
                    .frame(width: geometry.size.width, height: drawerHeight)
                    .background(Color.black)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                    )
                    .shadow(color: Color.black.opacity(0.28), radius: 18, x: 0, y: -6)
                    .offset(y: currentDrawerYOffset)
                }
                .ignoresSafeArea(edges: .bottom)
            }
            .navigationTitle("Business Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink(destination: BusinessTransactionHistoryView()) {
                        Label("History", systemImage: "clock.arrow.circlepath")
                    }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    NavigationLink(
                        destination: BusinessProfileView(profile: businessProfile) { updated in
                            businessProfile = updated
                        }
                    ) {
                        Label("Profile", systemImage: "gearshape.fill")
                    }
                    if let onLogout = onLogout {
                        Button("Logout", action: onLogout)
                    }
                }
            }
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
            .onChange(of: selectedTimeframe) { _, newTimeframe in
                Task {
                    await loadDashboardMetrics(for: newTimeframe)
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func snapScannerDrawer(open: Bool, closedTravelDistance: CGFloat) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            isScannerOpen = open
            scannerOffset = open ? -closedTravelDistance : 0
        }
    }
    
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

// MARK: - Summary Metric Card Component

private struct SummaryMetricCard: View {
    let title: String
    let subtitle: String
    let amount: Double
    let systemImage: String
    let accentColor: Color
    let badgeText: String
    let isLoading: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(accentColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: systemImage)
                        .font(.title3.weight(.semibold))
                        .foregroundColor(accentColor)
                }
                
                Spacer()
                
                Text(badgeText)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(accentColor.opacity(0.12))
                    )
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.secondary)
                
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(String(format: "₱%.2f", amount))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .contentTransition(.numericText())
                    
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(accentColor.opacity(0.2), lineWidth: 1)
        )
    }
}
