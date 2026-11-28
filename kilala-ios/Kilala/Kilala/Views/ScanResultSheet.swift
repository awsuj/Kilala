//
//  ScanResultSheet.swift
//  Kilala
//
//  Created by Joshua Calibo on 10/22/26.
//

import SwiftUI

struct ScanResultSheet: View {
    let result: VerificationResponse
    var manualQRToken: Binding<String>? = nil
    let onDismiss: () -> Void

    private func handleDismissAndReset() {
        manualQRToken?.wrappedValue = ""
        onDismiss()
    }
    
    @State private var billAmountText: String = ""
    @State private var isRecordingTransaction: Bool = false
    @State private var showConfirmationAlert: Bool = false
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    
    private enum VerificationState {
        case valid
        case expired
        case invalid
    }

    private var verificationState: VerificationState {
        if result.isValid {
            return .valid
        }
        let statusUpper = result.cardholderSummary?.status.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() ?? ""
        if statusUpper == "EXPIRED" || result.message.localizedCaseInsensitiveContains("expired") {
            return .expired
        }
        return .invalid
    }

    private var themeColor: Color {
        switch verificationState {
        case .valid: return .kilalaStateValid
        case .expired: return .kilalaStateExpired
        case .invalid: return .kilalaStateInvalid
        }
    }

    private var bannerForegroundColor: Color {
        switch verificationState {
        case .valid, .invalid: return .white
        case .expired: return .kilalaInk
        }
    }

    private var bannerIconColor: Color {
        switch verificationState {
        case .valid: return .kilalaSunrise
        case .expired: return .kilalaInk
        case .invalid: return .white
        }
    }

    private var statusIconName: String {
        switch verificationState {
        case .valid: return "checkmark.seal.fill"
        case .expired: return "clock.badge.exclamationmark.fill"
        case .invalid: return "xmark.octagon.fill"
        }
    }

    private var statusTitle: String {
        switch verificationState {
        case .valid: return "VERIFIED"
        case .expired: return "EXPIRED"
        case .invalid: return result.cardholderSummary == nil ? "NOT RECOGNIZED" : "INVALID / REVOKED"
        }
    }

    /// Readable state accent color on light surfaces (Mint/White).
    private var readableStateTextColor: Color {
        switch verificationState {
        case .valid: return .kilalaStateValid
        case .expired: return .kilalaInk
        case .invalid: return .kilalaStateInvalid
        }
    }
    
    private var originalAmount: Double {
        Double(billAmountText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0.0
    }
    
    private var discountValue: Double {
        originalAmount * 0.20
    }
    
    private var discountedAmount: Double {
        originalAmount * 0.80
    }
    
    private var isValidBillAmount: Bool {
        originalAmount > 0
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.kilalaPaper
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Status Banner Header (16pt radius)
                        VStack(spacing: 8) {
                            Image(systemName: statusIconName)
                                .font(.system(size: 52))
                                .foregroundColor(bannerIconColor)
                                .accessibilityHidden(true)
                            
                            Text(statusTitle)
                                .font(.kilala(.title2, weight: .bold))
                                .tracking(0.8)
                                .foregroundColor(bannerForegroundColor)
                            
                            Text(result.message)
                                .font(.kilala(.callout, weight: .medium))
                                .foregroundColor(bannerForegroundColor.opacity(0.92))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .padding(.horizontal, 16)
                        .background(themeColor)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        
                        // Cardholder Details Card (Crisp White 16pt Card)
                        if let cardholder = result.cardholderSummary {
                            VStack(spacing: 16) {
                                // Cardholder Photo & Primary Identity
                                HStack(spacing: 16) {
                                    CardholderAvatarView(photoUrl: cardholder.photoUrl, borderColor: themeColor)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(cardholder.fullName)
                                            .font(.kilala(.title3, weight: .bold))
                                            .foregroundColor(.kilalaInk)
                                        
                                        Text(cardholder.lguName.uppercased())
                                            .font(.kilala(.caption, weight: .bold))
                                            .tracking(0.6)
                                            .foregroundColor(.kilalaInkSecondary)
                                        
                                        Text(cardholder.lguIdNumber)
                                            .font(.kilalaMono(.callout, weight: .semibold))
                                            .foregroundColor(readableStateTextColor)
                                    }
                                    
                                    Spacer()
                                }
                                
                                Divider()
                                    .overlay(Color.kilalaMintBorder)
                                
                                // Metadata Rows
                                VStack(spacing: 12) {
                                    DetailRow(label: "LGU", value: cardholder.lguName)
                                    DetailRow(label: "ID Number", value: cardholder.lguIdNumber, isMonospaced: true)
                                    DetailRow(
                                        label: "Privilege Type",
                                        value: cardholder.privilegeType.replacingOccurrences(of: "_", with: " ")
                                    )
                                    
                                    if let disabilityType = cardholder.disabilityType, !disabilityType.isEmpty {
                                        DetailRow(label: "Disability Type", value: disabilityType)
                                    }
                                    
                                    DetailRow(label: "Card Status", value: cardholder.status, valueColor: readableStateTextColor)
                                }
                            }
                            .padding(16)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.kilalaMintBorder, lineWidth: 1)
                            )
                            
                            // Transaction Recording Section (Valid Green State Only)
                            if result.isValid {
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("Apply 20% Statutory Discount")
                                        .font(.kilala(.headline, weight: .bold))
                                        .foregroundColor(.kilalaInk)
                                    
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Total Bill Amount (₱)")
                                            .font(.kilala(.subheadline, weight: .bold))
                                            .foregroundColor(.kilalaInk)
                                        
                                        TextField(
                                            "Total Bill Amount",
                                            text: $billAmountText,
                                            prompt: Text("Total Bill Amount").foregroundStyle(Color.kilalaInk.opacity(0.4))
                                        )
                                            .keyboardType(.decimalPad)
                                            .font(.kilala(.title3, weight: .semibold))
                                            .foregroundColor(.kilalaInk)
                                            .tint(.kilalaGreen)
                                            .padding(.horizontal, 12)
                                            .frame(minHeight: 50)
                                            .background(Color.kilalaPaper.opacity(0.6))
                                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                    .stroke(Color.kilalaBorder, lineWidth: 1)
                                            )
                                    }
                                    
                                    Divider()
                                        .overlay(Color.kilalaMintBorder)
                                    
                                    VStack(spacing: 8) {
                                        DetailRow(
                                            label: "Original Amount",
                                            value: String(format: "₱%.2f", originalAmount)
                                        )
                                        DetailRow(
                                            label: "20% Discount",
                                            value: String(format: "-₱%.2f", discountValue),
                                            valueColor: .kilalaStateValid
                                        )
                                        HStack {
                                            Text("Final Discounted Total")
                                                .font(.kilala(.headline, weight: .bold))
                                                .foregroundColor(.kilalaInk)
                                            Spacer()
                                            Text(String(format: "₱%.2f", discountedAmount))
                                                .font(.kilala(.title3, weight: .bold))
                                                .foregroundColor(.kilalaGreen)
                                        }
                                        .padding(.top, 4)
                                    }
                                    
                                    Button(action: {
                                        recordTransaction(cardholderId: cardholder.id.uuidString)
                                    }) {
                                        Text("Record Transaction")
                                            .font(.kilala(.headline, weight: .bold))
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 52)
                                            .background(isValidBillAmount ? Color.kilalaGreen : Color.kilalaInkMuted)
                                            .foregroundColor(.white)
                                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    }
                                    .disabled(!isValidBillAmount || isRecordingTransaction)
                                }
                                .padding(16)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(Color.kilalaMintBorder, lineWidth: 1)
                                )
                            }
                        } else {
                            // Unrecognized / Counterfeit QR Code Fallback
                            VStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.title)
                                    .foregroundColor(.kilalaStateInvalid)
                                    .accessibilityHidden(true)
                                
                                Text("No Matching Cardholder Record")
                                    .font(.kilala(.headline, weight: .bold))
                                    .foregroundColor(.kilalaInk)
                                
                                Text("This QR code is not registered in the Kilala database or has been rotated by the cardholder. Do not honor mandatory discount privileges for this scan.")
                                    .font(.kilala(.subheadline))
                                    .foregroundColor(.kilalaInkSecondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.kilalaStateInvalid.opacity(0.35), lineWidth: 1)
                            )
                        }
                        
                        Button(action: handleDismissAndReset) {
                            Text(result.isValid ? "Scan Next Customer" : "Dismiss & Scan Again")
                                .font(.kilala(.headline, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(result.isValid ? Color.kilalaMint : themeColor)
                                .foregroundColor(result.isValid ? .kilalaGreen : bannerForegroundColor)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(result.isValid ? Color.kilalaMintBorder : Color.clear, lineWidth: 1)
                                )
                        }
                    }
                    .padding(16)
                }
                .scrollDismissesKeyboard(.interactively)
                
                // Loading Overlay
                if isRecordingTransaction {
                    Color.kilalaInk.opacity(0.35)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 14) {
                        ProgressView()
                            .tint(.kilalaGreen)
                            .scaleEffect(1.3)
                        Text("Recording Transaction...")
                            .font(.kilala(.subheadline, weight: .semibold))
                            .foregroundColor(.kilalaInk)
                    }
                    .padding(24)
                    .background(Color.kilalaPaper)
                    .cornerRadius(16)
                    .shadow(color: Color.kilalaInk.opacity(0.16), radius: 10)
                }
            }
            .navigationTitle("Verification Result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.kilalaPaper, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done", action: handleDismissAndReset)
                        .font(.kilala(.subheadline, weight: .semibold))
                        .foregroundColor(.kilalaGreen)
                        .disabled(isRecordingTransaction)
                }
            }
            .alert("Transaction Recorded", isPresented: $showConfirmationAlert) {
                Button("Record Next") {
                    handleDismissAndReset()
                }
            } message: {
                Text(
                    String(
                        format: "Successfully recorded bill of ₱%.2f with a 20%% discount (Final: ₱%.2f).",
                        originalAmount,
                        discountedAmount
                    )
                )
            }
            .alert("Transaction Failed", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func recordTransaction(cardholderId: String) {
        guard isValidBillAmount && !isRecordingTransaction else { return }
        
        isRecordingTransaction = true
        
        Task {
            do {
                _ = try await APIService.shared.recordTransaction(
                    cardholderId: cardholderId,
                    originalAmount: originalAmount,
                    discountedAmount: discountedAmount
                )
                isRecordingTransaction = false
                showConfirmationAlert = true
            } catch {
                isRecordingTransaction = false
                errorMessage = error.localizedDescription
                showErrorAlert = true
            }
        }
    }
}

private struct CardholderAvatarView: View {
    let photoUrl: String?
    let borderColor: Color
    
    var body: some View {
        Group {
            if let photoUrl = photoUrl,
               !photoUrl.isEmpty,
               let url = URL(string: photoUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        placeholderIcon
                    case .empty:
                        ProgressView()
                    @unknown default:
                        placeholderIcon
                    }
                }
            } else {
                placeholderIcon
            }
        }
        .frame(width: 72, height: 72)
        .background(Color.white)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(borderColor, lineWidth: 2.5)
        )
    }
    
    private var placeholderIcon: some View {
        Image(systemName: "person.crop.circle.fill")
            .resizable()
            .scaledToFit()
            .foregroundColor(.kilalaInkMuted)
            .padding(6)
    }
}

private struct DetailRow: View {
    let label: String
    let value: String
    var valueColor: Color = .kilalaInk
    var isMonospaced: Bool = false
    
    var body: some View {
        HStack {
            Text(label)
                .font(.kilala(.subheadline))
                .foregroundColor(.kilalaInkSecondary)
            Spacer()
            Text(value)
                .font(isMonospaced ? .kilalaMono(.subheadline, weight: .semibold) : .kilala(.subheadline, weight: .semibold))
                .foregroundColor(valueColor)
        }
    }
}
