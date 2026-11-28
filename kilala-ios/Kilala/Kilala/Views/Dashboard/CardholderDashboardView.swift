//
//  CardholderDashboardView.swift
//  Kilala
//
//  Created by Eunice Santos on 11/22/26.
//

import SwiftUI
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

struct CardholderDashboardView: View {
    let token: String
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

    @State private var selectedTab: Tab = .home
    @State private var profile: CardholderProfile? = nil
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var isQRRevealed: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch selectedTab {
                case .home:
                    CardholderHomeView(
                        profile: profile,
                        isLoading: isLoading,
                        errorMessage: errorMessage,
                        isQRRevealed: $isQRRevealed,
                        onRetry: {
                            Task {
                                await loadProfile(force: true)
                            }
                        },
                        onLogout: onLogout
                    )

                case .transactions:
                    NavigationStack {
                        CardholderTransactionHistoryView(token: token)
                    }

                case .profile:
                    NavigationStack {
                        CardholderProfileView(
                            token: token,
                            profile: profile,
                            onLogout: onLogout
                        ) { updatedProfile in
                            profile = updatedProfile
                        }
                    }
                    .tint(.kilalaGreen)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Flat, Compact Bottom Tab Bar anchored to bottom safe area
            CardholderFlatTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onAppear {
            if !token.isEmpty {
                APIService.shared.authToken = token
            }
        }
        .task {
            await loadProfile(force: false)
        }
        .onChange(of: selectedTab) { _, newTab in
            if newTab != .home {
                isQRRevealed = false
            }
        }
    }

    private func loadProfile(force: Bool) async {
        if !force && profile != nil {
            return
        }

        let activeToken = token.isEmpty ? (APIService.shared.authToken ?? "") : token
        isLoading = true
        errorMessage = nil

        do {
            let fetchedProfile = try await APIService.shared.getCardholderProfile(token: activeToken)
            profile = fetchedProfile
            isLoading = false
        } catch is CancellationError {
            // Task cancelled
        } catch {
            errorMessage = "Could not load Digital ID."
            isLoading = false
        }
    }
}

// MARK: - Flat, Compact Bottom Tab Bar

private struct CardholderFlatTabBar: View {
    @Binding var selectedTab: CardholderDashboardView.Tab

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.kilalaBorder)
                .frame(height: 1)

            HStack(spacing: 0) {
                ForEach(CardholderDashboardView.Tab.allCases, id: \.self) { tab in
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

// MARK: - Cardholder Home Tab View

struct CardholderHomeView: View {
    let profile: CardholderProfile?
    let isLoading: Bool
    let errorMessage: String?
    @Binding var isQRRevealed: Bool
    let onRetry: () -> Void
    var onLogout: (() -> Void)? = nil

    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.kilalaPaper
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 14) {
                    // Stacked Mobile Editorial Header (No Top Logout Button)
                    BusinessPortalHeader(title: "My Kilala ID")
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                    if let profile = profile {
                        VStack(spacing: 12) {
                            Spacer(minLength: 0)

                            digitalIDCard(for: profile)
                                .padding(.horizontal, 16)
                                .animation(.easeInOut(duration: 0.25), value: isQRRevealed)

                            Spacer(minLength: 4)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let errorMessage = errorMessage, !isLoading {
                        VStack {
                            Spacer()
                            errorStateCard(message: errorMessage)
                                .padding(.horizontal, 16)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        VStack {
                            Spacer()
                            loadingStateCard
                                .padding(.horizontal, 16)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .navigationTitle("My Kilala ID")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: - Digital ID & QR Card Container

    private func digitalIDCard(for profile: CardholderProfile) -> some View {
        let badge = classificationBadge(for: profile.privilegeType)
        let statusAppearance = statusBadgeAppearance(for: profile.status)
        let displayName = formattedDisplayName(for: profile)
        let isPWD = profile.privilegeType.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == "PWD"
        let trimmedDisability = (profile.disabilityType ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        return VStack(spacing: 14) {
            // Cardholder Header Info
            VStack(spacing: 6) {
                Text(profile.lguName.uppercased())
                    .font(.kilala(.caption, weight: .bold))
                    .tracking(0.8)
                    .foregroundColor(.kilalaInkSecondary)

                // Full Name with Middle Initial (masked with "*" while preserving middle initial period when hidden)
                Text(isQRRevealed ? displayName : maskedFullName(from: displayName))
                    .font(.kilala(size: 22, weight: .bold, relativeTo: .title2))
                    .foregroundColor(.kilalaInk)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                // LGU ID Number on its own line (blurred when hidden, unblurred when revealed)
                Text(profile.lguIdNumber)
                    .font(.kilalaMono(.subheadline, weight: .semibold))
                    .foregroundColor(.kilalaInkSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .blur(radius: isQRRevealed ? 0 : 6)

                // Classification Badge + PWD Disability Type on the same horizontal line (always unblurred)
                HStack(alignment: .center, spacing: 8) {
                    KilalaStatusBadge(
                        icon: badge.icon,
                        label: formattedPrivilegeType(from: profile.privilegeType),
                        foreground: badge.foreground,
                        background: badge.fill,
                        cornerRadius: 8
                    )

                    if isPWD && !trimmedDisability.isEmpty {
                        Text("•")
                            .font(.kilala(.footnote, weight: .bold))
                            .foregroundColor(.kilalaInkMuted)
                            .accessibilityHidden(true)

                        Text(trimmedDisability)
                            .font(.kilala(.footnote, weight: .semibold))
                            .foregroundColor(.kilalaInkSecondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .padding(.top, 2)
            }

            // Interactive Privacy-Blurred QR Code Centerpiece
            ZStack {
                Image(uiImage: generateQRCode(from: profile.qrSecretToken))
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(10)
                    .scaleEffect(isQRRevealed ? 1.0 : 0.97)
                    .blur(radius: isQRRevealed ? 0 : 8)

                // Frosted / Blurred Privacy Cover Overlay
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(0.70)

                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.kilalaPaper.opacity(0.52))

                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color.kilalaMint)
                                .frame(width: 48, height: 48)
                                .overlay(
                                    Circle()
                                        .stroke(Color.kilalaMintBorder, lineWidth: 1)
                                )

                            Image(systemName: "eye.slash.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.kilalaGreen)
                        }

                        Text("Tap or swipe to show QR code")
                            .font(.kilala(.subheadline, weight: .bold))
                            .foregroundColor(.kilalaInk)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 20)
                }
                .opacity(isQRRevealed ? 0 : 1)
                .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.kilalaMintBorder, lineWidth: 1)
            )
            .shadow(color: Color.kilalaInk.opacity(0.05), radius: 8, x: 0, y: 4)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .onTapGesture {
                isQRRevealed.toggle()
            }
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { _ in
                        isQRRevealed.toggle()
                    }
            )

            // Subtle Interaction Hint & Card Status Badge
            VStack(spacing: 10) {
                Text(isQRRevealed ? "Tap or swipe QR code to hide" : "QR code is hidden for your privacy")
                    .font(.kilala(.caption, weight: .medium))
                    .foregroundColor(.kilalaInkSecondary)

                KilalaStatusBadge(
                    icon: statusAppearance.icon,
                    label: "Status: \(statusAppearance.label)",
                    foreground: statusAppearance.foreground,
                    background: statusAppearance.background,
                    cornerRadius: 8
                )
            }
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.kilalaMintBorder, lineWidth: 1)
        )
        .shadow(color: Color.kilalaInk.opacity(0.04), radius: 10, x: 0, y: 4)
    }

    // MARK: - Loading & Error States

    private var loadingStateCard: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(.kilalaGreen)

            Text("Loading Digital ID...")
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

    private func errorStateCard(message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32, weight: .semibold))
                .foregroundColor(.kilalaStateInvalid)
                .accessibilityHidden(true)

            Text(message)
                .font(.kilala(.callout, weight: .bold))
                .foregroundColor(.kilalaInk)
                .multilineTextAlignment(.center)

            Button(action: onRetry) {
                Text("Retry")
                    .font(.kilala(.subheadline, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .frame(minHeight: 44)
                    .background(Color.kilalaGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.kilalaStateInvalid.opacity(0.35), lineWidth: 1)
        )
    }

    // MARK: - Formatting & QR Helpers

    private func classificationBadge(for rawType: String) -> (icon: String, fill: Color, foreground: Color) {
        switch rawType.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
        case "PWD":
            return ("figure.roll", Color.kilalaGreen.opacity(0.12), .kilalaGreen)
        case "SENIOR_CITIZEN":
            return ("person.crop.circle.badge.checkmark", Color.kilalaSunrise.opacity(0.30), .kilalaInk)
        default:
            return ("person.text.rectangle", Color.kilalaMint, .kilalaInk)
        }
    }

    private func statusBadgeAppearance(for rawStatus: String) -> (icon: String, label: String, foreground: Color, background: Color) {
        let normalized = rawStatus.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        switch normalized {
        case "ACTIVE":
            return (
                "checkmark.circle.fill",
                "ACTIVE",
                .kilalaStateValid,
                Color.kilalaStateValid.opacity(0.12)
            )
        case "EXPIRED":
            return (
                "clock.badge.exclamationmark.fill",
                "EXPIRED",
                .kilalaInk,
                Color.kilalaStateExpired.opacity(0.28)
            )
        case "REVOKED", "SUSPENDED":
            return (
                "xmark.circle.fill",
                normalized,
                .kilalaStateInvalid,
                Color.kilalaStateInvalid.opacity(0.12)
            )
        default:
            let label = normalized.isEmpty ? "ACTIVE" : normalized
            return (
                "checkmark.circle.fill",
                label,
                .kilalaStateValid,
                Color.kilalaStateValid.opacity(0.12)
            )
        }
    }

    /// Formats the cardholder's name with their middle name shortened to a single initial followed by a period
    /// (e.g., "Juan Santos Dela Cruz" -> "Juan S. Dela Cruz"; omits middle initial if no middle name is set).
    private func formattedDisplayName(for profile: CardholderProfile) -> String {
        let trimmedFirst = profile.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedMiddle = (profile.middleName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLast = profile.lastName.trimmingCharacters(in: .whitespacesAndNewlines)

        let middleInitial: String? = {
            guard let firstChar = trimmedMiddle.first(where: { $0.isLetter }) ?? trimmedMiddle.first else {
                return nil
            }
            return "\(String(firstChar).uppercased())."
        }()

        return [trimmedFirst, middleInitial, trimmedLast]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// Masks each word after its first character with "*" while preserving the period on any middle initial
    /// (e.g., "Juan S. Dela Cruz" -> "J*** S. D*** C***").
    private func maskedFullName(from fullName: String) -> String {
        fullName
            .split(separator: " ")
            .map { word in
                guard let firstChar = word.first else { return "" }
                let maskedRest = String(
                    word.dropFirst().map { $0 == "." ? "." : "*" }
                )
                return "\(firstChar)\(maskedRest)"
            }
            .joined(separator: " ")
    }

    private func formattedPrivilegeType(from rawType: String) -> String {
        switch rawType.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
        case "PWD":
            return "PWD"
        case "SENIOR_CITIZEN":
            return "Senior Citizen"
        default:
            return rawType
        }
    }

    func generateQRCode(from string: String) -> UIImage {
        filter.message = Data(string.utf8)
        if let outputImage = filter.outputImage {
            let scaledImage = outputImage.samplingNearest().transformed(by: CGAffineTransform(scaleX: 10, y: 10))
            if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
                return UIImage(cgImage: cgImage)
            }
        }
        return UIImage(systemName: "xmark.circle") ?? UIImage()
    }
}
