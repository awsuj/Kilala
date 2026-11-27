//
//  CreateAccountView.swift
//  Kilala
//
//  Created by Eunice Santos on 11/14/26.
//

import SwiftUI

struct CreateAccountView: View {
    // MARK: - Properties

    let profileId: UUID
    var verifiedFullName: String? = nil
    var verifiedCardNumber: String? = nil
    var verifiedPrivilegeLabel: String? = nil
    var onRegistrationSuccess: ((LoginResponse) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var isPasswordVisible: Bool = false
    @State private var isConfirmPasswordVisible: Bool = false

    @State private var isEmailVerified: Bool = false
    @State private var verifiedEmail: String = ""
    @State private var navigateToOTP: Bool = false

    @State private var isSendingOTP: Bool = false
    @State private var isCreatingAccount: Bool = false
    @State private var errorMessage: String? = nil
    @State private var standaloneSession: LoginResponse? = nil

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case email
        case password
        case confirmPassword
    }

    // MARK: - Password Validation Computed Properties

    private var hasMinLength: Bool { password.count >= 8 }
    private var hasUppercase: Bool { password.range(of: "[A-Z]", options: .regularExpression) != nil }
    private var hasNumber: Bool { password.range(of: "[0-9]", options: .regularExpression) != nil }
    private var hasSpecialChar: Bool {
        password.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil
    }
    private var isPasswordValid: Bool {
        hasMinLength && hasUppercase && hasNumber && hasSpecialChar
    }
    private var passwordsMatch: Bool {
        !confirmPassword.isEmpty && password == confirmPassword
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.kilalaPaper
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    // Editorial Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("STEP 2 OF 2 · ACCOUNT DETAILS")
                            .font(.kilala(.caption, weight: .bold))
                            .tracking(0.8)
                            .foregroundColor(.kilalaGreen)

                        Text("Create Your Account")
                            .font(.kilala(size: 28, weight: .bold, relativeTo: .title))
                            .foregroundColor(.kilalaInk)

                        Text("Set up your login credentials and verify your email address to claim your Kilala Digital ID.")
                            .font(.kilala(.callout))
                            .foregroundColor(.kilalaInkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 8)

                    // Compact Verified LGU Record Banner
                    if let verifiedFullName, !verifiedFullName.isEmpty {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(.kilalaStateValid)
                                .padding(.top, 1)
                                .accessibilityHidden(true)

                            VStack(alignment: .leading, spacing: 3) {
                                Text("LGU record verified")
                                    .font(.kilala(.footnote, weight: .bold))
                                    .foregroundColor(.kilalaStateValid)

                                Text(verifiedFullName)
                                    .font(.kilala(.callout, weight: .bold))
                                    .foregroundColor(.kilalaInk)

                                if let verifiedPrivilegeLabel, !verifiedPrivilegeLabel.isEmpty {
                                    Text(verifiedPrivilegeLabel)
                                        .font(.kilala(.footnote))
                                        .foregroundColor(.kilalaInkSecondary)
                                }

                                if let verifiedCardNumber, !verifiedCardNumber.isEmpty {
                                    Text("ID: \(verifiedCardNumber)")
                                        .font(.kilalaMono(.caption, weight: .medium))
                                        .foregroundColor(.kilalaInkSecondary)
                                }
                            }

                            Spacer()

                            Button("Change") {
                                dismiss()
                            }
                            .font(.kilala(.footnote, weight: .bold))
                            .foregroundColor(.kilalaGreen)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.kilalaMint)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.kilalaMintBorder, lineWidth: 1)
                        )
                    }

                    // Account Credentials Card
                    VStack(alignment: .leading, spacing: 8) {
                        sectionHeader("Account Credentials")

                        VStack(alignment: .leading, spacing: 16) {
                            // Email Address
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    fieldLabel("Email Address *")

                                    Spacer()

                                    if isEmailVerified {
                                        KilalaStatusBadge(
                                            icon: "checkmark.circle.fill",
                                            label: "Verified",
                                            foreground: .kilalaStateValid,
                                            background: Color.kilalaStateValid.opacity(0.12),
                                            cornerRadius: 8
                                        )
                                    }
                                }

                                TextField(
                                    "Email Address *",
                                    text: $email,
                                    prompt: Text(verbatim: "name@example.com").foregroundStyle(Color.kilalaInk.opacity(0.4))
                                )
                                .font(.kilala(.body))
                                .foregroundColor(.kilalaInk)
                                .tint(.kilalaGreen)
                                .keyboardType(.emailAddress)
                                .textContentType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .submitLabel(.next)
                                .focused($focusedField, equals: .email)
                                .onSubmit { focusedField = .password }
                                .onChange(of: email) { _, newValue in
                                    let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                                    if isEmailVerified && trimmed != verifiedEmail.lowercased() {
                                        isEmailVerified = false
                                    }
                                }
                                .kilalaCardholderInputChrome(isFocused: focusedField == .email)
                            }

                            // Create Password
                            VStack(alignment: .leading, spacing: 8) {
                                fieldLabel("Create Password *")

                                HStack(spacing: 8) {
                                    Group {
                                        if isPasswordVisible {
                                            TextField("Create a password", text: $password)
                                                .textInputAutocapitalization(.never)
                                                .autocorrectionDisabled()
                                        } else {
                                            SecureField("Create a password", text: $password)
                                        }
                                    }
                                    .font(.kilala(.body))
                                    .foregroundColor(.kilalaInk)
                                    .tint(.kilalaGreen)
                                    .textContentType(.newPassword)
                                    .submitLabel(.next)
                                    .focused($focusedField, equals: .password)
                                    .onSubmit { focusedField = .confirmPassword }

                                    Button {
                                        let wasFocused = (focusedField == .password)
                                        isPasswordVisible.toggle()
                                        if wasFocused {
                                            DispatchQueue.main.async {
                                                focusedField = .password
                                            }
                                        }
                                    } label: {
                                        Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.kilalaInkSecondary)
                                            .frame(width: 28, height: 28)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(isPasswordVisible ? "Hide password" : "Show password")
                                }
                                .kilalaCardholderInputChrome(isFocused: focusedField == .password)

                                // Password Rules
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Password must contain:")
                                        .font(.kilala(.caption, weight: .bold))
                                        .foregroundColor(.kilalaInkSecondary)

                                    PasswordRuleRow(text: "At least 8 characters", isMet: hasMinLength)
                                    PasswordRuleRow(text: "At least 1 uppercase letter", isMet: hasUppercase)
                                    PasswordRuleRow(text: "At least 1 number", isMet: hasNumber)
                                    PasswordRuleRow(text: "At least 1 special character", isMet: hasSpecialChar)
                                }
                                .padding(.top, 2)
                            }

                            // Confirm Password
                            VStack(alignment: .leading, spacing: 8) {
                                fieldLabel("Confirm Password *")

                                HStack(spacing: 8) {
                                    Group {
                                        if isConfirmPasswordVisible {
                                            TextField("Re-enter your password", text: $confirmPassword)
                                                .textInputAutocapitalization(.never)
                                                .autocorrectionDisabled()
                                        } else {
                                            SecureField("Re-enter your password", text: $confirmPassword)
                                        }
                                    }
                                    .font(.kilala(.body))
                                    .foregroundColor(.kilalaInk)
                                    .tint(.kilalaGreen)
                                    .textContentType(.newPassword)
                                    .submitLabel(.done)
                                    .focused($focusedField, equals: .confirmPassword)
                                    .onSubmit { focusedField = nil }

                                    Button {
                                        let wasFocused = (focusedField == .confirmPassword)
                                        isConfirmPasswordVisible.toggle()
                                        if wasFocused {
                                            DispatchQueue.main.async {
                                                focusedField = .confirmPassword
                                            }
                                        }
                                    } label: {
                                        Image(systemName: isConfirmPasswordVisible ? "eye.slash" : "eye")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.kilalaInkSecondary)
                                            .frame(width: 28, height: 28)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(isConfirmPasswordVisible ? "Hide confirm password" : "Show confirm password")
                                }
                                .kilalaCardholderInputChrome(isFocused: focusedField == .confirmPassword)

                                if !confirmPassword.isEmpty && !passwordsMatch {
                                    Text("Passwords do not match.")
                                        .font(.kilala(.caption, weight: .semibold))
                                        .foregroundColor(.kilalaStateInvalid)
                                }
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

                    if let errorMessage = errorMessage {
                        inlineErrorBanner(errorMessage)
                    }

                    // Action Buttons
                    VStack(spacing: 14) {
                        // Send OTP to Email Button (Green Outline Style Mirroring Change Password)
                        Button(action: handleSendOTP) {
                            HStack(spacing: 8) {
                                if isSendingOTP {
                                    ProgressView()
                                        .tint(.kilalaGreen)
                                    Text("Sending Verification Code...")
                                        .font(.kilala(.callout, weight: .bold))
                                } else {
                                    Image(systemName: "envelope.fill")
                                        .font(.system(size: 15, weight: .semibold))
                                        .accessibilityHidden(true)

                                    Text(isEmailVerified ? "Resend OTP to email" : "Send OTP to email")
                                        .font(.kilala(.callout, weight: .bold))
                                }
                            }
                            .foregroundColor(.kilalaGreen)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.kilalaMintBorder, lineWidth: 1)
                            )
                        }
                        .disabled(isSendingOTP || isCreatingAccount)
                        .opacity((isSendingOTP || isCreatingAccount) ? 0.55 : 1.0)

                        // Create Account Button + Helper Note
                        VStack(alignment: .center, spacing: 8) {
                            Text("Your email must be verified first in order to create your account.")
                                .font(.kilala(.footnote))
                                .foregroundColor(.kilalaInkSecondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity, alignment: .center)

                            Button(action: handleCreateAccount) {
                                HStack(spacing: 8) {
                                    if isCreatingAccount {
                                        ProgressView()
                                            .tint(.white)
                                        Text("Creating Account...")
                                            .font(.kilala(.headline, weight: .bold))
                                            .foregroundColor(.white)
                                    } else {
                                        Text("Create Account")
                                            .font(.kilala(.headline, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Color.kilalaGreen)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .disabled(!isEmailVerified || isCreatingAccount || isSendingOTP)
                            .opacity((!isEmailVerified || isCreatingAccount || isSendingOTP) ? 0.55 : 1.0)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle("Create Account")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.kilalaPaper, for: .navigationBar)
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
                CardholderDashboardView(token: session.token) {
                    APIService.shared.authToken = nil
                    standaloneSession = nil
                }
            }
        }
    }

    // MARK: - Form Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.kilala(.caption, weight: .bold))
            .tracking(0.8)
            .foregroundColor(.kilalaInkSecondary)
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(.kilala(.subheadline, weight: .bold))
            .foregroundColor(.kilalaInk)
    }

    private func inlineErrorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.kilalaStateInvalid)
                .padding(.top, 1)
                .accessibilityHidden(true)

            Text(message)
                .font(.kilala(.subheadline, weight: .semibold))
                .foregroundColor(.kilalaStateInvalid)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.kilalaStateInvalid.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.kilalaStateInvalid.opacity(0.30), lineWidth: 1)
        )
    }

    // MARK: - Actions & Networking

    private func handleSendOTP() {
        focusedField = nil
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
        focusedField = nil
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

// MARK: - Password Rule Row & Secure Field Helpers

struct PasswordRuleRow: View {
    let text: String
    let isMet: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isMet ? .kilalaStateValid : .kilalaInkMuted)
                .accessibilityHidden(true)

            Text(text)
                .font(.kilala(.caption, weight: isMet ? .semibold : .regular))
                .foregroundColor(isMet ? .kilalaStateValid : .kilalaInkSecondary)
        }
    }
}

struct CustomSecureField: View {
    @Binding var text: String

    var body: some View {
        SecureField("", text: $text)
            .font(.kilala(.body))
            .foregroundColor(.kilalaInk)
            .tint(.kilalaGreen)
            .kilalaCardholderInputChrome(isFocused: false)
    }
}

struct CreateAccountView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            CreateAccountView(profileId: UUID())
        }
    }
}
