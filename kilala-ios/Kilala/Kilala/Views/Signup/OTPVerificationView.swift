//
//  OTPVerificationView.swift
//  Kilala
//
//  Created by Eunice Santos on 11/14/26.
//

import SwiftUI
import Combine

struct OTPVerificationView: View {
    // MARK: - Verification Mode

    enum Mode {
        case signup
        case emailChange(
            token: String,
            onVerified: (String) -> Void,
            onProfileVerified: ((CardholderProfile) -> Void)?
        )
        case businessEmailChange(
            token: String,
            onVerified: (String) -> Void
        )
    }

    // MARK: - Properties

    let email: String
    @Binding var isEmailVerified: Bool
    private let mode: Mode

    @Environment(\.dismiss) private var dismiss

    @State private var otp: String = ""
    @State private var isLoading: Bool = false
    @State private var isResending: Bool = false
    @State private var resendCooldown: Int = 30
    @State private var errorMessage: String? = nil
    @State private var infoMessage: String? = nil

    @FocusState private var isOTPFieldFocused: Bool

    private let cooldownTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // MARK: - Computed Properties

    private var isEmailChangeMode: Bool {
        switch mode {
        case .emailChange, .businessEmailChange:
            return true
        case .signup:
            return false
        }
    }

    private var trimmedOTP: String {
        otp.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canVerify: Bool {
        !isLoading && !isResending && trimmedOTP.count == 6
    }

    // MARK: - Initialization

    init(
        email: String,
        isEmailVerified: Binding<Bool>
    ) {
        self.email = email
        self._isEmailVerified = isEmailVerified
        self.mode = .signup
    }

    init(
        email: String,
        token: String = APIService.shared.authToken ?? "",
        onProfileVerified: ((CardholderProfile) -> Void)? = nil,
        onVerified: @escaping (String) -> Void
    ) {
        self.email = email
        self._isEmailVerified = .constant(false)
        self.mode = .emailChange(
            token: token,
            onVerified: onVerified,
            onProfileVerified: onProfileVerified
        )
    }

    init(
        businessEmail: String,
        token: String = APIService.shared.authToken ?? "",
        onVerified: @escaping (String) -> Void
    ) {
        self.email = businessEmail
        self._isEmailVerified = .constant(false)
        self.mode = .businessEmailChange(
            token: token,
            onVerified: onVerified
        )
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.kilalaPaper
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    headerSection

                    otpInputCard

                    if let errorMessage = errorMessage {
                        inlineErrorBanner(message: errorMessage)
                    }

                    if let infoMessage = infoMessage {
                        inlineSuccessBanner(message: infoMessage)
                    }

                    actionButtonsSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 96)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle(isEmailChangeMode ? "Verify New Email" : "Verify Email")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(Color.kilalaPaper, for: .navigationBar)
        .tint(.kilalaGreen)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                isOTPFieldFocused = true
            }
        }
        .onReceive(cooldownTimer) { _ in
            if resendCooldown > 0 {
                resendCooldown -= 1
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(isEmailChangeMode ? "Confirm Email Change" : "Verify Your Email")
                    .font(.kilala(size: 24, weight: .bold, relativeTo: .title2))
                    .foregroundColor(.kilalaInk)

                Text(
                    isEmailChangeMode
                        ? "Enter the 6-digit verification code sent to your new email address before we update your account."
                        : "Enter the 6-digit verification code we sent to your email address."
                )
                .font(.kilala(.subheadline))
                .foregroundColor(.kilalaInkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            // Target Email Pill
            HStack(spacing: 8) {
                Image(systemName: "envelope.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.kilalaGreen)
                    .accessibilityHidden(true)

                Text(email)
                    .font(.kilala(.footnote, weight: .bold))
                    .foregroundColor(.kilalaInk)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color.kilalaMint)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.kilalaMintBorder, lineWidth: 1)
            )
        }
    }

    // MARK: - OTP Input Card

    private var otpInputCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("6-DIGIT VERIFICATION CODE")
                    .font(.kilala(.caption, weight: .bold))
                    .tracking(0.8)
                    .foregroundColor(.kilalaInkSecondary)

                Spacer()

                Text("\(trimmedOTP.count)/6")
                    .font(.kilalaMono(.caption, weight: .semibold))
                    .foregroundColor(trimmedOTP.count == 6 ? .kilalaGreen : .kilalaInkMuted)
            }

            // 6-Digit Segmented Code Boxes backed by a native one-time-code TextField
            ZStack {
                HStack(spacing: 8) {
                    ForEach(0..<6, id: \.self) { index in
                        otpDigitBox(at: index)
                    }
                }

                TextField("", text: $otp)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($isOTPFieldFocused)
                    .foregroundColor(.clear)
                    .accentColor(.clear)
                    .tint(.clear)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.white.opacity(0.015))
                    .onChange(of: otp) { _, newValue in
                        if errorMessage != nil { errorMessage = nil }
                        let filtered = newValue.filter { $0.isNumber }
                        if filtered.count > 6 {
                            otp = String(filtered.prefix(6))
                        } else if filtered != newValue {
                            otp = filtered
                        }
                    }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                isOTPFieldFocused = true
            }

            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.kilalaInkMuted)
                    .accessibilityHidden(true)

                Text("Verification codes are valid for 10 minutes.")
                    .font(.kilala(.caption))
                    .foregroundColor(.kilalaInkSecondary)
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
    }

    private func otpDigitBox(at index: Int) -> some View {
        let digits = Array(trimmedOTP)
        let characterString = index < digits.count ? String(digits[index]) : ""
        let isCurrentActiveSlot = isOTPFieldFocused && (
            index == digits.count || (digits.count == 6 && index == 5)
        )
        let isFilled = !characterString.isEmpty

        return ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isFilled ? Color.kilalaMint.opacity(0.45) : Color.kilalaPaper.opacity(0.65))

            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    isCurrentActiveSlot
                        ? Color.kilalaGreen
                        : (isFilled ? Color.kilalaMintBorder : Color.kilalaBorder),
                    lineWidth: isCurrentActiveSlot ? 1.5 : 1
                )

            if isFilled {
                Text(characterString)
                    .font(.kilalaMono(size: 22, weight: .bold))
                    .foregroundColor(.kilalaInk)
            } else if isCurrentActiveSlot {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.kilalaGreen)
                    .frame(width: 2, height: 20)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 54)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Digit \(index + 1)")
        .accessibilityValue(isFilled ? characterString : "Empty")
    }

    // MARK: - Inline Feedback Banners

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

    private func inlineSuccessBanner(message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.kilalaStateValid)
                .accessibilityHidden(true)

            Text(message)
                .font(.kilala(.footnote, weight: .semibold))
                .foregroundColor(.kilalaStateValid)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.kilalaStateValid.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.kilalaStateValid.opacity(0.30), lineWidth: 1)
        )
    }

    // MARK: - Action Buttons (12pt Radius)

    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            // Primary Verify Button
            Button(action: handleVerifyOTP) {
                HStack(spacing: 8) {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                        Text("Verifying Code...")
                    } else {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .accessibilityHidden(true)

                        Text(isEmailChangeMode ? "Verify & Update Email" : "Verify Email")
                    }
                }
                .font(.kilala(.callout, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(canVerify ? Color.kilalaGreen : Color.kilalaInkMuted)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .disabled(!canVerify)

            // Resend OTP Button with Cooldown Timer
            Button(action: handleResendOTP) {
                HStack(spacing: 8) {
                    if isResending {
                        ProgressView()
                            .tint(.kilalaGreen)
                        Text("Sending New Code...")
                            .font(.kilala(.callout, weight: .semibold))
                            .foregroundColor(.kilalaInkSecondary)
                    } else if resendCooldown > 0 {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .semibold))
                            .accessibilityHidden(true)

                        Text("Resend Code in \(resendCooldown)s")
                            .font(.kilala(.callout, weight: .semibold))
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .semibold))
                            .accessibilityHidden(true)

                        Text("Resend Verification Code")
                            .font(.kilala(.callout, weight: .bold))
                    }
                }
                .foregroundColor(resendCooldown > 0 ? .kilalaInkSecondary : .kilalaGreen)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            resendCooldown > 0 ? Color.kilalaBorder : Color.kilalaMintBorder,
                            lineWidth: 1
                        )
                )
            }
            .disabled(isLoading || isResending || resendCooldown > 0)

            // Secondary Cancel / Back Button
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
            .disabled(isLoading || isResending)
        }
    }

    // MARK: - Actions & Networking

    private func handleVerifyOTP() {
        isOTPFieldFocused = false
        errorMessage = nil
        infoMessage = nil

        guard trimmedOTP.count == 6 else {
            errorMessage = "Please enter the 6-digit verification code."
            return
        }

        isLoading = true

        Task {
            do {
                switch mode {
                case .signup:
                    try await APIService.shared.verifyOTP(email: email, otp: trimmedOTP)
                    await MainActor.run {
                        self.isLoading = false
                        self.isEmailVerified = true
                        dismiss()
                    }

                case .emailChange(let token, let onVerified, let onProfileVerified):
                    let activeToken = token.isEmpty ? (APIService.shared.authToken ?? "") : token
                    let updatedProfile = try await APIService.shared.verifyCardholderEmailChange(
                        token: activeToken,
                        pendingEmail: email,
                        otp: trimmedOTP
                    )
                    await MainActor.run {
                        self.isLoading = false
                        let verifiedEmail = updatedProfile.email ?? email
                        onProfileVerified?(updatedProfile)
                        onVerified(verifiedEmail)
                        dismiss()
                    }

                case .businessEmailChange(let token, let onVerified):
                    let activeToken = token.isEmpty ? (APIService.shared.authToken ?? "") : token
                    let verifiedEmail = try await APIService.shared.verifyBusinessEmailChange(
                        token: activeToken,
                        pendingEmail: email,
                        otp: trimmedOTP
                    )
                    await MainActor.run {
                        self.isLoading = false
                        onVerified(verifiedEmail)
                        dismiss()
                    }
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
                switch mode {
                case .signup:
                    try await APIService.shared.requestRegistrationOTP(email: email)

                case .emailChange(let token, _, _):
                    let activeToken = token.isEmpty ? (APIService.shared.authToken ?? "") : token
                    try await APIService.shared.resendCardholderEmailChangeOTP(
                        token: activeToken,
                        pendingEmail: email
                    )

                case .businessEmailChange(let token, _):
                    let activeToken = token.isEmpty ? (APIService.shared.authToken ?? "") : token
                    try await APIService.shared.resendBusinessEmailChangeOTP(
                        token: activeToken,
                        pendingEmail: email
                    )
                }

                await MainActor.run {
                    self.isResending = false
                    self.resendCooldown = 30
                    self.infoMessage = "A new 6-digit verification code has been sent to \(email)."
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

// MARK: - Previews

struct OTPVerificationView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            OTPVerificationView(email: "juan@example.com", isEmailVerified: .constant(false))
        }
    }
}
