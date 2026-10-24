//
//  ScanResultSheet.swift
//  Kilala
//
//  Created by Joshua Calibo on 10/22/26.
//

import SwiftUI

struct ScanResultSheet: View {
    let result: VerificationResponse
    let onDismiss: () -> Void
    
    @State private var billAmountText: String = ""
    @State private var isRecordingTransaction: Bool = false
    @State private var showConfirmationAlert: Bool = false
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    
    private var themeColor: Color {
        result.isValid ? .green : .red
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
                ScrollView {
                    VStack(spacing: 20) {
                        // Status Banner Header
                        VStack(spacing: 10) {
                            Image(systemName: result.isValid ? "checkmark.seal.fill" : "xmark.octagon.fill")
                                .font(.system(size: 56))
                                .foregroundColor(.white)
                            
                            Text(result.isValid ? "VERIFIED" : "INVALID / REVOKED")
                                .font(.title2.weight(.heavy))
                                .tracking(1)
                                .foregroundColor(.white)
                            
                            Text(result.message)
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.white.opacity(0.95))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .padding(.horizontal, 16)
                        .background(themeColor.gradient)
                        .cornerRadius(20)
                        
                        // Cardholder Details Card
                        if let cardholder = result.cardholderSummary {
                            VStack(spacing: 16) {
                                // Cardholder Photo & Primary Identity
                                HStack(spacing: 16) {
                                    CardholderAvatarView(photoUrl: cardholder.photoUrl, borderColor: themeColor)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(cardholder.fullName)
                                            .font(.title3.bold())
                                            .foregroundColor(.primary)
                                        
                                        Text(cardholder.lguName.uppercased())
                                            .font(.caption.weight(.bold))
                                            .foregroundColor(.secondary)
                                        
                                        Text(cardholder.lguIdNumber)
                                            .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                                            .foregroundColor(themeColor)
                                    }
                                    
                                    Spacer()
                                }
                                
                                Divider()
                                
                                // Metadata Rows
                                VStack(spacing: 10) {
                                    DetailRow(label: "LGU", value: cardholder.lguName)
                                    DetailRow(label: "ID Number", value: cardholder.lguIdNumber)
                                    DetailRow(
                                        label: "Privilege Type",
                                        value: cardholder.privilegeType.replacingOccurrences(of: "_", with: " ")
                                    )
                                    
                                    if let disabilityType = cardholder.disabilityType, !disabilityType.isEmpty {
                                        DetailRow(label: "Disability Type", value: disabilityType)
                                    }
                                    
                                    DetailRow(label: "Card Status", value: cardholder.status, valueColor: themeColor)
                                }
                            }
                            .padding(18)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(themeColor.opacity(0.35), lineWidth: 1.5)
                            )
                            
                            // Transaction Recording Section (Valid Green State Only)
                            if result.isValid {
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("Apply 20% Statutory Discount")
                                        .font(.headline)
                                    
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Total Bill Amount (₱)")
                                            .font(.subheadline.weight(.medium))
                                            .foregroundColor(.secondary)
                                        
                                        TextField("Total Bill Amount", text: $billAmountText)
                                            .keyboardType(.decimalPad)
                                            .font(.title3.weight(.semibold))
                                            .padding(12)
                                            .background(Color(.systemBackground))
                                            .cornerRadius(10)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                            )
                                    }
                                    
                                    Divider()
                                    
                                    VStack(spacing: 8) {
                                        DetailRow(
                                            label: "Original Amount",
                                            value: String(format: "₱%.2f", originalAmount)
                                        )
                                        DetailRow(
                                            label: "20% Discount",
                                            value: String(format: "-₱%.2f", discountValue),
                                            valueColor: .green
                                        )
                                        HStack {
                                            Text("Final Discounted Total")
                                                .font(.headline)
                                            Spacer()
                                            Text(String(format: "₱%.2f", discountedAmount))
                                                .font(.title3.bold())
                                                .foregroundColor(.green)
                                        }
                                        .padding(.top, 4)
                                    }
                                    
                                    Button(action: {
                                        recordTransaction(cardholderId: cardholder.id.uuidString)
                                    }) {
                                        Text("Record Transaction")
                                            .font(.headline)
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(isValidBillAmount ? Color.green : Color.gray.opacity(0.5))
                                            .foregroundColor(.white)
                                            .cornerRadius(12)
                                    }
                                    .disabled(!isValidBillAmount || isRecordingTransaction)
                                }
                                .padding(18)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.green.opacity(0.35), lineWidth: 1.5)
                                )
                            }
                        } else {
                            // Unrecognized / Counterfeit QR Code Fallback
                            VStack(spacing: 10) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(.red)
                                
                                Text("No Matching Cardholder Record")
                                    .font(.headline)
                                
                                Text("This QR code is not registered in the Kilala database or has been rotated by the cardholder. Do not honor mandatory discount privileges for this scan.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(20)
                            .frame(maxWidth: .infinity)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(16)
                        }
                        
                        Button(action: onDismiss) {
                            Text(result.isValid ? "Scan Next Customer" : "Dismiss & Scan Again")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(result.isValid ? Color(.tertiarySystemFill) : themeColor)
                                .foregroundColor(result.isValid ? .primary : .white)
                                .cornerRadius(12)
                        }
                        .padding(.top, 4)
                    }
                    .padding()
                }
                
                // Loading Overlay
                if isRecordingTransaction {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 14) {
                        ProgressView()
                            .scaleEffect(1.3)
                        Text("Recording Transaction...")
                            .font(.subheadline.weight(.semibold))
                    }
                    .padding(24)
                    .background(.regularMaterial)
                    .cornerRadius(16)
                    .shadow(radius: 10)
                }
            }
            .navigationTitle("Verification Result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done", action: onDismiss)
                        .disabled(isRecordingTransaction)
                }
            }
            .alert("Transaction Recorded", isPresented: $showConfirmationAlert) {
                Button("OK") {
                    onDismiss()
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
        .background(Color(.tertiarySystemBackground))
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
            .foregroundColor(.secondary)
            .padding(6)
    }
}

private struct DetailRow: View {
    let label: String
    let value: String
    var valueColor: Color = .primary
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(valueColor)
        }
    }
}
