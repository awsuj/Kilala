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

    enum Tab: Hashable {
        case home
        case transactions
        case profile
    }

    @State private var selectedTab: Tab = .home
    @State private var profile: CardholderProfile? = nil
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var isQRRevealed: Bool = false

    var body: some View {
        TabView(selection: $selectedTab) {
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
            .tabItem {
                Label("Home", systemImage: selectedTab == .home ? "house.fill" : "house")
            }
            .tag(Tab.home)

            Color.clear
                .tabItem {
                    Label("Transactions", systemImage: "list.bullet.rectangle")
                }
                .tag(Tab.transactions)

            Color.clear
                .tabItem {
                    Label("Profile", systemImage: selectedTab == .profile ? "person.fill" : "person")
                }
                .tag(Tab.profile)
        }
        .tint(.black)
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
                Color.white
                    .ignoresSafeArea()

                if let profile = profile {
                    VStack(spacing: 16) {
                        Spacer(minLength: 8)

                        // Digital ID & QR Card Container
                        VStack(spacing: 16) {
                            // Cardholder Header Info
                            VStack(spacing: 6) {
                                Text(profile.lguName.uppercased())
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .tracking(0.8)
                                    .foregroundColor(.gray)

                                // Full Name (masked with "*" from 2nd character of each word when hidden)
                                Text(isQRRevealed ? profile.fullName : maskedFullName(from: profile.fullName))
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.black)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)

                                // Privilege Type (always clear) + LGU ID Number (blurred when hidden)
                                HStack(spacing: 0) {
                                    Text("\(formattedPrivilegeType(from: profile.privilegeType)) • ")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(Color(white: 0.35))

                                    Text(profile.lguIdNumber)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(Color(white: 0.35))
                                        .blur(radius: isQRRevealed ? 0 : 6)
                                }
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)

                                if let disability = profile.disabilityType, !disability.isEmpty {
                                    Text(disability)
                                        .font(.footnote)
                                        .foregroundColor(.gray)
                                }
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
                                    .blur(radius: isQRRevealed ? 0 : 10)

                                // Frosted / Blurred Privacy Cover Overlay
                                ZStack {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(.ultraThinMaterial)

                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.white.opacity(0.65))

                                    VStack(spacing: 10) {
                                        ZStack {
                                            Circle()
                                                .fill(Color(white: 0.92))
                                                .frame(width: 46, height: 46)

                                            Image(systemName: "eye.slash.fill")
                                                .font(.system(size: 18, weight: .semibold))
                                                .foregroundColor(Color(white: 0.25))
                                        }

                                        Text("Tap or swipe to show QR code")
                                            .font(.footnote)
                                            .fontWeight(.semibold)
                                            .foregroundColor(Color(white: 0.25))
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
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
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

                            // Subtle interaction hint & Card Status
                            VStack(spacing: 10) {
                                Text(isQRRevealed ? "Tap or swipe QR code to hide" : "QR code is hidden for your privacy")
                                    .font(.caption)
                                    .foregroundColor(.gray)

                                Text("Status: \(profile.status)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(
                                        profile.status == "ACTIVE"
                                            ? Color.green.opacity(0.15)
                                            : Color.red.opacity(0.15)
                                    )
                                    .foregroundColor(profile.status == "ACTIVE" ? .green : .red)
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.vertical, 20)
                        .padding(.horizontal, 14)
                        .frame(maxWidth: .infinity)
                        .background(Color(white: 0.96))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                        )
                        .padding(.horizontal, 18)
                        .animation(.easeInOut(duration: 0.25), value: isQRRevealed)

                        Spacer(minLength: 8)
                    }
                } else if let errorMessage = errorMessage, !isLoading {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.circle")
                            .font(.system(size: 36))
                            .foregroundColor(.gray)

                        Text(errorMessage)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)

                        Button(action: onRetry) {
                            Text("Retry")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 28)
                                .padding(.vertical, 12)
                                .background(Color(white: 0.25))
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal, 32)
                } else {
                    ProgressView("Loading Digital ID...")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            .navigationTitle("My Kilala ID")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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

    private func maskedFullName(from fullName: String) -> String {
        fullName
            .split(separator: " ")
            .map { word in
                guard let firstChar = word.first else { return "" }
                let maskedRest = String(repeating: "*", count: max(0, word.count - 1))
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
