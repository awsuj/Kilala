//
//  OTPVerificationView.swift
//  Kilala
//
//  Created by Eunice Santos on 11/14/26.
//

import SwiftUI

struct OTPVerificationView: View {
    let email: String
    @Binding var isEmailVerified: Bool

    @Environment(\.dismiss) private var dismiss

    @State private var otp: String = ""
    @State private var isLoading: Bool = false
    @State private var isResending: Bool = false
    @State private var errorMessage: String? = nil
    @State private var infoMessage: String? = nil

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                // Custom top-left Back button
                Button(action: {
                    dismiss()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.subheadline.weight(.semibold))
                        Text("Back")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.black)
                }
                .padding(.top, 8)

                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Verify Email")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .padding(.bottom, 4)

                    Divider()
                        .background(Color.gray)
                        .padding(.bottom, 8)

                    Text("The OTP was sent to \(email).")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.gray)
                }

                // 6-digit OTP Input Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("6-Digit OTP")
                        .font(.footnote)
                        .fontWeight(.bold)

                    CustomTextField(text: $otp)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .onChange(of: otp) { _, newValue in
                            let filtered = newValue.filter { $0.isNumber }
                            if filtered.count > 6 {
                                otp = String(filtered.prefix(6))
                            } else if filtered != newValue {
                                otp = filtered
                            }
                        }
                }

                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                if let infoMessage = infoMessage {
                    Text(infoMessage)
                        .font(.footnote)
                        .foregroundColor(.green)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                // Verify Button
                Button(action: handleVerifyOTP) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(white: 0.25))
                            .cornerRadius(8)
                    } else {
                        Text("Verify")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(white: 0.25))
                            .cornerRadius(8)
                    }
                }
                .disabled(isLoading || isResending)
                .padding(.top, 10)

                // Resend OTP Button / Link
                Button(action: handleResendOTP) {
                    HStack {
                        Spacer()
                        if isResending {
                            ProgressView()
                                .padding(.trailing, 6)
                            Text("Resending OTP...")
                                .font(.footnote)
                                .fontWeight(.semibold)
                                .foregroundColor(.gray)
                        } else {
                            Text("Resend OTP")
                                .font(.footnote)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        }
                        Spacer()
                    }
                }
                .disabled(isLoading || isResending)
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 20)
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func handleVerifyOTP() {
        errorMessage = nil
        infoMessage = nil

        let trimmedOTP = otp.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedOTP.count == 6 else {
            errorMessage = "Please enter the 6-digit verification code."
            return
        }

        isLoading = true

        Task {
            do {
                try await APIService.shared.verifyOTP(email: email, otp: trimmedOTP)
                await MainActor.run {
                    self.isLoading = false
                    self.isEmailVerified = true
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    private func handleResendOTP() {
        errorMessage = nil
        infoMessage = nil
        isResending = true

        Task {
            do {
                try await APIService.shared.requestRegistrationOTP(email: email)
                await MainActor.run {
                    self.isResending = false
                    self.infoMessage = "A new OTP has been sent to \(email)."
                }
            } catch {
                await MainActor.run {
                    self.isResending = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}

struct OTPVerificationView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            OTPVerificationView(email: "juan@example.com", isEmailVerified: .constant(false))
        }
    }
}
