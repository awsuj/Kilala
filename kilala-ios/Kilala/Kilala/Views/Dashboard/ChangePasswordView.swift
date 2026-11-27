//
//  ChangePasswordView.swift
//  Kilala
//
//  Created by Eunice Santos on 11/24/26.
//

import SwiftUI

struct ChangePasswordView: View {
    // MARK: - Properties

    var token: String = APIService.shared.authToken ?? ""
    var onSuccess: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    // Form field state
    @State private var currentPassword: String = ""
    @State private var newPassword: String = ""
    @State private var confirmNewPassword: String = ""

    // Field visibility toggles
    @State private var isCurrentPasswordVisible: Bool = false
    @State private var isNewPasswordVisible: Bool = false
    @State private var isConfirmPasswordVisible: Bool = false

    // Submission & inline feedback state
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String? = nil

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case currentPassword
        case newPassword
        case confirmNewPassword
    }

    // MARK: - Password Validation Computed Properties

    private var activeToken: String {
        token.isEmpty ? (APIService.shared.authToken ?? "") : token
    }

    private var hasMinLength: Bool {
        newPassword.count >= 8
    }

    private var hasUppercase: Bool {
        newPassword.range(of: "[A-Z]", options: .regularExpression) != nil
    }

    private var hasNumber: Bool {
        newPassword.range(of: "[0-9]", options: .regularExpression) != nil
    }

    private var hasSpecialChar: Bool {
        newPassword.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil
    }

    private var isNewPasswordValid: Bool {
        hasMinLength && hasUppercase && hasNumber && hasSpecialChar
    }

    private var hasMismatchWarning: Bool {
        !confirmNewPassword.isEmpty && newPassword != confirmNewPassword
    }

    private var canSubmit: Bool {
        !isSubmitting &&
        !currentPassword.isEmpty &&
        !newPassword.isEmpty &&
        !confirmNewPassword.isEmpty
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.kilalaPaper
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    headerSection

                    passwordFormCard

                    if let errorMessage = errorMessage {
                        inlineErrorBanner(message: errorMessage)
                    }

                    actionButtonsSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 96)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle("Change Password")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(Color.kilalaPaper, for: .navigationBar)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Update Account Password")
                .font(.kilala(size: 22, weight: .bold, relativeTo: .title2))
                .foregroundColor(.kilalaInk)

            Text("Enter your current password and choose a strong new password for your Kilala account.")
                .font(.kilala(.subheadline))
                .foregroundColor(.kilalaInkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Password Form Card

    private var passwordFormCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            passwordInputField(
                label: "CURRENT PASSWORD",
                placeholder: "Enter current password",
                text: $currentPassword,
                isVisible: $isCurrentPasswordVisible,
                field: .currentPassword,
                submitLabel: .next
            ) {
                focusedField = .newPassword
            }

            Divider()
                .overlay(Color.kilalaMintBorder)

            VStack(alignment: .leading, spacing: 12) {
                passwordInputField(
                    label: "NEW PASSWORD",
                    placeholder: "Enter new password",
                    text: $newPassword,
                    isVisible: $isNewPasswordVisible,
                    field: .newPassword,
                    submitLabel: .next
                ) {
                    focusedField = .confirmNewPassword
                }

                passwordRequirementsChecklist
            }

            Divider()
                .overlay(Color.kilalaMintBorder)

            VStack(alignment: .leading, spacing: 6) {
                passwordInputField(
                    label: "CONFIRM NEW PASSWORD",
                    placeholder: "Re-enter new password",
                    text: $confirmNewPassword,
                    isVisible: $isConfirmPasswordVisible,
                    field: .confirmNewPassword,
                    submitLabel: .done
                ) {
                    focusedField = nil
                }

                if hasMismatchWarning {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.kilalaStateInvalid)
                            .accessibilityHidden(true)

                        Text("Passwords do not match")
                            .font(.kilala(.caption, weight: .semibold))
                            .foregroundColor(.kilalaStateInvalid)
                    }
                    .padding(.top, 2)
                }
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.kilalaMintBorder, lineWidth: 1)
        )
        .onChange(of: currentPassword) { _, _ in
            if errorMessage != nil { errorMessage = nil }
        }
        .onChange(of: newPassword) { _, _ in
            if errorMessage != nil { errorMessage = nil }
        }
        .onChange(of: confirmNewPassword) { _, _ in
            if errorMessage != nil { errorMessage = nil }
        }
    }

    // MARK: - Password Requirements Checklist

    private var passwordRequirementsChecklist: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Password must contain:")
                .font(.kilala(.caption, weight: .bold))
                .foregroundColor(.kilalaInkSecondary)

            passwordRuleRow(text: "At least 8 characters", isMet: hasMinLength)
            passwordRuleRow(text: "At least 1 uppercase letter", isMet: hasUppercase)
            passwordRuleRow(text: "At least 1 number", isMet: hasNumber)
            passwordRuleRow(text: "At least 1 special character", isMet: hasSpecialChar)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.kilalaPaper.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func passwordRuleRow(text: String, isMet: Bool) -> some View {
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

    // MARK: - Inline Error Banner

    private func inlineErrorBanner(message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.kilalaStateInvalid)
                .accessibilityHidden(true)

            Text(message)
                .font(.kilala(.footnote, weight: .semibold))
                .foregroundColor(.kilalaStateInvalid)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.kilalaStateInvalid.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.kilalaStateInvalid.opacity(0.35), lineWidth: 1)
        )
    }

    // MARK: - Action Buttons (12pt Radius)

    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            Button(action: handleSubmitPasswordChange) {
                HStack(spacing: 8) {
                    if isSubmitting {
                        ProgressView()
                            .tint(.white)
                        Text("Updating Password...")
                    } else {
                        Text("Update Password")
                    }
                }
                .font(.kilala(.callout, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(canSubmit ? Color.kilalaGreen : Color.kilalaInkMuted)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .disabled(!canSubmit)

            Button {
                dismiss()
            } label: {
                Text("Cancel")
                    .font(.kilala(.callout, weight: .semibold))
                    .foregroundColor(.kilalaInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.kilalaBorder, lineWidth: 1)
                    )
            }
            .disabled(isSubmitting)
        }
    }

    // MARK: - Field Components

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(.kilala(.caption, weight: .bold))
            .tracking(0.8)
            .foregroundColor(.kilalaInkSecondary)
    }

    private func passwordInputField(
        label: String,
        placeholder: String,
        text: Binding<String>,
        isVisible: Binding<Bool>,
        field: Field,
        submitLabel: SubmitLabel,
        onSubmit: @escaping () -> Void
    ) -> some View {
        let isFocused = focusedField == field

        return VStack(alignment: .leading, spacing: 8) {
            fieldLabel(label)

            HStack(spacing: 8) {
                Group {
                    if isVisible.wrappedValue {
                        TextField(
                            placeholder,
                            text: text,
                            prompt: Text(placeholder).foregroundStyle(Color.kilalaInk.opacity(0.4))
                        )
                    } else {
                        SecureField(
                            placeholder,
                            text: text,
                            prompt: Text(placeholder).foregroundStyle(Color.kilalaInk.opacity(0.4))
                        )
                    }
                }
                .font(.kilala(.body))
                .foregroundColor(.kilalaInk)
                .tint(.kilalaGreen)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: field)
                .submitLabel(submitLabel)
                .onSubmit(onSubmit)

                Button {
                    isVisible.wrappedValue.toggle()
                } label: {
                    Image(systemName: isVisible.wrappedValue ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.kilalaInkSecondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isVisible.wrappedValue ? "Hide password" : "Show password")
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 48)
            .background(Color.kilalaPaper.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isFocused ? Color.kilalaGreen : Color.kilalaBorder,
                        lineWidth: isFocused ? 1.5 : 1
                    )
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Actions & Networking

    private func handleSubmitPasswordChange() {
        focusedField = nil
        errorMessage = nil

        guard !currentPassword.isEmpty else {
            errorMessage = "Please enter your current password."
            return
        }

        guard isNewPasswordValid else {
            errorMessage = "New password does not meet all security requirements."
            return
        }

        guard newPassword == confirmNewPassword else {
            errorMessage = "New passwords do not match."
            return
        }

        guard currentPassword != newPassword else {
            errorMessage = "New password must be different from your current password."
            return
        }

        isSubmitting = true

        Task {
            do {
                try await APIService.shared.changePassword(
                    token: activeToken,
                    currentPassword: currentPassword,
                    newPassword: newPassword
                )
                await MainActor.run {
                    isSubmitting = false
                    onSuccess?()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
