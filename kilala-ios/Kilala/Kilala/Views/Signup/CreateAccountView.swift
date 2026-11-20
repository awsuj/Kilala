//
//  CreateAccountView.swift
//  Kilala
//
//  Created by Eunice Santos on 11/14/26.
//

import SwiftUI

struct CreateAccountView: View {
    let profileId: UUID
    var onRegistrationSuccess: ((LoginResponse) -> Void)? = nil

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""

    @State private var isEmailVerified: Bool = false
    @State private var verifiedEmail: String = ""
    @State private var navigateToOTP: Bool = false

    @State private var isSendingOTP: Bool = false
    @State private var isCreatingAccount: Bool = false
    @State private var errorMessage: String? = nil
    @State private var standaloneSession: LoginResponse? = nil

    private var hasMinLength: Bool { password.count >= 8 }
    private var hasUppercase: Bool { password.range(of: "[A-Z]", options: .regularExpression) != nil }
    private var hasNumber: Bool { password.range(of: "[0-9]", options: .regularExpression) != nil }
    private var hasSpecialChar: Bool {
        password.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil
    }
    private var isPasswordValid: Bool {
        hasMinLength && hasUppercase && hasNumber && hasSpecialChar
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Register Account")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .padding(.bottom, 4)

                    Divider()
                        .background(Color.gray)
                        .padding(.bottom, 8)

                    Text("Create your account credentials")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.gray)
                }
                .padding(.top, 16)

                // Email Address
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Email Address")
                            .font(.footnote)
                            .fontWeight(.bold)
                        Spacer()
                        if isEmailVerified {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Verified")
                            }
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                        }
                    }

                    CustomTextField(text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: email) { _, newValue in
                            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                            if isEmailVerified && trimmed != verifiedEmail.lowercased() {
                                isEmailVerified = false
                            }
                        }
                }

                // Create Password
                VStack(alignment: .leading, spacing: 8) {
                    Text("Create Password")
                        .font(.footnote)
                        .fontWeight(.bold)

                    CustomSecureField(text: $password)

                    // Password Rules
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Password must contain:")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.gray)

                        PasswordRuleRow(text: "At least 8 characters", isMet: hasMinLength)
                        PasswordRuleRow(text: "At least 1 uppercase letter", isMet: hasUppercase)
                        PasswordRuleRow(text: "At least 1 number", isMet: hasNumber)
                        PasswordRuleRow(text: "At least 1 special character", isMet: hasSpecialChar)
                    }
                    .padding(.top, 4)
                }

                // Confirm Password
                VStack(alignment: .leading, spacing: 8) {
                    Text("Confirm Password")
                        .font(.footnote)
                        .fontWeight(.bold)

                    CustomSecureField(text: $confirmPassword)
                }

                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                // Primary Button: Send OTP to email
                Button(action: handleSendOTP) {
                    if isSendingOTP {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(white: 0.25))
                            .cornerRadius(8)
                    } else {
                        Text("Send OTP to email")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(white: 0.25))
                            .cornerRadius(8)
                    }
                }
                .disabled(isSendingOTP || isCreatingAccount)
                .padding(.top, 10)

                // Secondary Button: Create Account + Helper Note
                VStack(alignment: .center, spacing: 8) {
                    Text("Your email must be verified first in order to create your account.")
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)

                    Button(action: handleCreateAccount) {
                        if isCreatingAccount {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.blue)
                                .cornerRadius(8)
                        } else {
                            Text("Create Account")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(isEmailVerified ? .white : .gray)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(isEmailVerified ? Color.blue : Color(white: 0.88))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(isEmailVerified ? Color.clear : Color.gray.opacity(0.5), lineWidth: 1)
                                )
                        }
                    }
                    .disabled(!isEmailVerified || isCreatingAccount || isSendingOTP)
                }
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 20)
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateToOTP) {
            OTPVerificationView(
                email: verifiedEmail,
                isEmailVerified: $isEmailVerified
            )
        }
        .fullScreenCover(isPresented: Binding(
            get: { standaloneSession != nil },
            set: { if !$0 { standaloneSession = nil } }
        )) {
            if let session = standaloneSession {
                DigitalIDView(token: session.token) {
                    APIService.shared.authToken = nil
                    standaloneSession = nil
                }
            }
        }
    }

    private func handleSendOTP() {
        errorMessage = nil
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedEmail.isEmpty, trimmedEmail.contains("@"), trimmedEmail.contains(".") else {
            errorMessage = "Please enter a valid email address."
            return
        }

        isSendingOTP = true

        Task {
            do {
                try await APIService.shared.requestRegistrationOTP(email: trimmedEmail)
                await MainActor.run {
                    self.verifiedEmail = trimmedEmail
                    self.isSendingOTP = false
                    self.navigateToOTP = true
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isSendingOTP = false
                }
            }
        }
    }

    private func handleCreateAccount() {
        guard isEmailVerified else { return }
        errorMessage = nil

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else {
            errorMessage = "Please enter your email address."
            return
        }

        guard isPasswordValid else {
            errorMessage = "Password does not meet all requirements."
            return
        }

        guard password == confirmPassword else {
            errorMessage = "Passwords do not match."
            return
        }

        isCreatingAccount = true

        Task {
            do {
                let response = try await APIService.shared.claimAccount(
                    profileId: profileId,
                    email: trimmedEmail,
                    password: password
                )
                await MainActor.run {
                    self.isCreatingAccount = false
                    if let onRegistrationSuccess = onRegistrationSuccess {
                        onRegistrationSuccess(response)
                    } else {
                        self.standaloneSession = response
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isCreatingAccount = false
                }
            }
        }
    }
}

struct PasswordRuleRow: View {
    let text: String
    let isMet: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                .font(.caption2)
                .foregroundColor(isMet ? .green : .gray)
            Text(text)
                .font(.caption)
                .foregroundColor(isMet ? .green : .gray)
        }
    }
}

struct CustomSecureField: View {
    @Binding var text: String

    var body: some View {
        SecureField("", text: $text)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(Color(white: 0.92))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.6), lineWidth: 1)
            )
    }
}

struct CreateAccountView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            CreateAccountView(profileId: UUID())
        }
    }
}
