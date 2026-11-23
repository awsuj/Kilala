//
//  BusinessSignupView.swift
//  Kilala
//
//  Created by Joshua Calibo on 10/23/26.
//

import SwiftUI

struct BusinessSignupView: View {
    var onRegistrationSuccess: (LoginResponse) -> Void

    // Stage tracking
    @State private var verifiedBusiness: BusinessVerificationResponse? = nil

    // Stage 1: LGU Selection & Verification Inputs
    @State private var lgus: [LGU] = []
    @State private var selectedLGUId: UUID? = nil
    @State private var manualLGUName = ""
    @State private var isLoadingLGUs = false
    @State private var businessName = ""
    @State private var tinNumber = ""
    @State private var isVerifyingBusiness = false
    @State private var verificationError: String? = nil

    // Stage 2: Profile & Account Details
    @State private var branchName = ""
    @State private var selectedCategory = "OTHER"
    @State private var businessPermitNo = ""
    @State private var address = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isSendingOTP = false
    @State private var accountError: String? = nil

    // Stage 3: OTP Navigation
    @State private var otpEmail = ""
    @State private var isEmailVerified = false
    @State private var navigateToOTP = false

    @FocusState private var focusedField: Field?

    private enum Field {
        case businessName
        case manualLGU
        case tinNumber
        case address
        case branchName
        case permitNo
        case email
        case password
        case confirmPassword
    }

    private let categories = [
        "PHARMACY",
        "RESTAURANT",
        "GROCERY",
        "TRANSPORT",
        "MEDICAL",
        "ENTERTAINMENT",
        "OTHER"
    ]

    private var selectedLGU: LGU? {
        lgus.first(where: { $0.id == selectedLGUId })
    }

    private var resolvedLGUName: String {
        if let selectedLGU {
            return selectedLGU.municipalityName
        }
        return manualLGUName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isStage1Valid: Bool {
        !businessName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !resolvedLGUName.isEmpty &&
        !businessPermitNo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !tinNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

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

    private var isStage2Valid: Bool {
        !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        isPasswordValid &&
        passwordsMatch
    }

    var body: some View {
        ZStack {
            Color.kilalaPaper
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    if let matched = verifiedBusiness {
                        stage2Content(matched: matched)
                    } else {
                        stage1Content
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle("Register Business")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.kilalaPaper, for: .navigationBar)
        .task {
            await loadLGUs()
        }
        .navigationDestination(isPresented: $navigateToOTP) {
            OTPVerificationView(
                email: otpEmail,
                isEmailVerified: $isEmailVerified,
                onOTPVerified: {
                    try await completeBusinessClaim()
                }
            )
        }
    }

    // MARK: - Stage 1: Verify Business Accreditation

    private var stage1Content: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Editorial Header
            VStack(alignment: .leading, spacing: 4) {
                Text("STEP 1 OF 2 · VERIFY ACCREDITATION")
                    .font(.kilala(.caption, weight: .bold))
                    .tracking(0.8)
                    .foregroundColor(.kilalaGreen)

                Text("Verify Your Business")
                    .font(.kilala(size: 28, weight: .bold, relativeTo: .title))
                    .foregroundColor(.kilalaInk)

                Text("Match your LGU-accredited business record before creating your merchant account.")
                    .font(.kilala(.callout))
                    .foregroundColor(.kilalaInkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 8)

            // Accreditation Lookup Card
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader("Accreditation Details")

                VStack(alignment: .leading, spacing: 16) {
                    // Business Name
                    VStack(alignment: .leading, spacing: 8) {
                        fieldLabel("Business Name *")
                        TextField(
                            "Business Name *",
                            text: $businessName,
                            prompt: Text("e.g., Mercury Drug").foregroundStyle(Color.kilalaInk.opacity(0.4))
                        )
                        .font(.kilala(.body))
                        .foregroundColor(.kilalaInk)
                        .tint(.kilalaGreen)
                        .submitLabel(.next)
                        .focused($focusedField, equals: .businessName)
                        .onSubmit {
                            focusedField = lgus.isEmpty ? .manualLGU : .permitNo
                        }
                        .kilalaInputChrome(isFocused: focusedField == .businessName)
                    }

                    // Issuing LGU
                    VStack(alignment: .leading, spacing: 8) {
                        fieldLabel("Issuing LGU *")

                        if isLoadingLGUs {
                            HStack(spacing: 12) {
                                ProgressView()
                                    .tint(.kilalaGreen)
                                Text("Loading LGUs...")
                                    .font(.kilala(.callout))
                                    .foregroundColor(.kilalaInkSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(minHeight: 48)
                        } else if lgus.isEmpty {
                            HStack(spacing: 10) {
                                TextField(
                                    "Issuing LGU *",
                                    text: $manualLGUName,
                                    prompt: Text("e.g., Makati City").foregroundStyle(Color.kilalaInk.opacity(0.4))
                                )
                                .font(.kilala(.body))
                                .foregroundColor(.kilalaInk)
                                .tint(.kilalaGreen)
                                .submitLabel(.next)
                                .focused($focusedField, equals: .manualLGU)
                                .onSubmit { focusedField = .permitNo }
                                .kilalaInputChrome(isFocused: focusedField == .manualLGU)

                                Button("Retry") {
                                    Task { await loadLGUs() }
                                }
                                .font(.kilala(.subheadline, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .frame(minHeight: 48)
                                .background(Color.kilalaGreen)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                        } else {
                            Menu {
                                ForEach(lgus) { lgu in
                                    Button {
                                        selectedLGUId = lgu.id
                                    } label: {
                                        HStack {
                                            Text("\(lgu.municipalityName) (\(lgu.lguCode))")
                                            if selectedLGUId == lgu.id {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(
                                        selectedLGU.map { "\($0.municipalityName) (\($0.lguCode))" }
                                            ?? "Select an LGU"
                                    )
                                    .font(.kilala(.body))
                                    .foregroundColor(selectedLGU == nil ? .kilalaInkSecondary : .kilalaInk)
                                    .lineLimit(1)

                                    Spacer()

                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.kilalaInkSecondary)
                                        .accessibilityHidden(true)
                                }
                                .padding(.horizontal, 12)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 48)
                                .background(Color.kilalaPaper.opacity(0.6))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.kilalaBorder, lineWidth: 1)
                                )
                            }
                        }
                    }

                    // Business Permit Number
                    VStack(alignment: .leading, spacing: 8) {
                        fieldLabel("Business Permit Number *")
                        TextField(
                            "Business Permit Number *",
                            text: $businessPermitNo,
                            prompt: Text(verbatim: "MKT-BP-2026-00001").foregroundStyle(Color.kilalaInk.opacity(0.4))
                        )
                        .font(.kilalaMono(.body, weight: .medium))
                        .foregroundColor(.kilalaInk)
                        .tint(.kilalaGreen)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .submitLabel(.next)
                        .focused($focusedField, equals: .permitNo)
                        .onSubmit { focusedField = .tinNumber }
                        .kilalaInputChrome(isFocused: focusedField == .permitNo)
                    }

                    // TIN Number
                    VStack(alignment: .leading, spacing: 8) {
                        fieldLabel("TIN Number *")
                        TextField(
                            "TIN Number *",
                            text: $tinNumber,
                            prompt: Text(verbatim: "000-123-456-000").foregroundStyle(Color.kilalaInk.opacity(0.4))
                        )
                        .font(.kilalaMono(.body, weight: .medium))
                        .foregroundColor(.kilalaInk)
                        .tint(.kilalaGreen)
                        .keyboardType(.numbersAndPunctuation)
                        .autocorrectionDisabled()
                        .submitLabel(.go)
                        .focused($focusedField, equals: .tinNumber)
                        .onSubmit {
                            if isStage1Valid && !isVerifyingBusiness {
                                handleVerifyBusiness()
                            }
                        }
                        .kilalaInputChrome(isFocused: focusedField == .tinNumber)
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

            if let verificationError {
                inlineErrorBanner(verificationError)
            }

            // Primary Verify Button
            Button(action: handleVerifyBusiness) {
                HStack(spacing: 8) {
                    if isVerifyingBusiness {
                        ProgressView()
                            .tint(.white)
                        Text("Verifying Business...")
                            .font(.kilala(.headline, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Text("Verify Business")
                            .font(.kilala(.headline, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.kilalaGreen)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .disabled(!isStage1Valid || isVerifyingBusiness)
            .opacity((!isStage1Valid || isVerifyingBusiness) ? 0.55 : 1.0)
        }
    }

    // MARK: - Stage 2: Account & Profile Details

    private func stage2Content(matched: BusinessVerificationResponse) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            // Editorial Header
            VStack(alignment: .leading, spacing: 4) {
                Text("STEP 2 OF 2 · ACCOUNT DETAILS")
                    .font(.kilala(.caption, weight: .bold))
                    .tracking(0.8)
                    .foregroundColor(.kilalaGreen)

                Text("Complete Registration")
                    .font(.kilala(size: 28, weight: .bold, relativeTo: .title))
                    .foregroundColor(.kilalaInk)

                Text("Confirm your business details and set up your login credentials for OTP verification.")
                    .font(.kilala(.callout))
                    .foregroundColor(.kilalaInkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 8)

            // Compact Verified Banner
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.kilalaStateValid)
                    .padding(.top, 1)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Accredited record found")
                        .font(.kilala(.footnote, weight: .bold))
                        .foregroundColor(.kilalaStateValid)

                    Text(matched.businessName)
                        .font(.kilala(.callout, weight: .bold))
                        .foregroundColor(.kilalaInk)

                    Text(matched.lguName ?? resolvedLGUName)
                        .font(.kilala(.footnote))
                        .foregroundColor(.kilalaInkSecondary)

                    if let permitNo = matched.businessPermitNo, !permitNo.isEmpty {
                        Text("Permit: \(permitNo)")
                            .font(.kilalaMono(.caption, weight: .medium))
                            .foregroundColor(.kilalaInkSecondary)
                    }
                }

                Spacer()

                Button("Change") {
                    resetToStage1()
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

            // Business Profile Details Card
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader("Business Profile")

                VStack(alignment: .leading, spacing: 16) {
                    // Business Address
                    VStack(alignment: .leading, spacing: 8) {
                        fieldLabel("Business Address *")
                        TextField(
                            "Business Address *",
                            text: $address,
                            prompt: Text("Street, Barangay, City").foregroundStyle(Color.kilalaInk.opacity(0.4)),
                            axis: .vertical
                        )
                        .lineLimit(1...3)
                        .font(.kilala(.body))
                        .foregroundColor(.kilalaInk)
                        .tint(.kilalaGreen)
                        .focused($focusedField, equals: .address)
                        .kilalaInputChrome(isFocused: focusedField == .address)
                    }

                    // Branch Name
                    VStack(alignment: .leading, spacing: 8) {
                        fieldLabel("Branch Name (Optional)")
                        TextField(
                            "Branch Name (Optional)",
                            text: $branchName,
                            prompt: Text("e.g., Glorietta 4 Branch").foregroundStyle(Color.kilalaInk.opacity(0.4))
                        )
                        .font(.kilala(.body))
                        .foregroundColor(.kilalaInk)
                        .tint(.kilalaGreen)
                        .submitLabel(.next)
                        .focused($focusedField, equals: .branchName)
                        .onSubmit { focusedField = .email }
                        .kilalaInputChrome(isFocused: focusedField == .branchName)
                    }

                    // Category Picker
                    VStack(alignment: .leading, spacing: 8) {
                        fieldLabel("Category")
                        Menu {
                            ForEach(categories, id: \.self) { category in
                                Button {
                                    selectedCategory = category
                                } label: {
                                    HStack {
                                        Text(category.capitalized)
                                        if selectedCategory == category {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Text(selectedCategory.capitalized)
                                    .font(.kilala(.body))
                                    .foregroundColor(.kilalaInk)

                                Spacer()

                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.kilalaInkSecondary)
                                    .accessibilityHidden(true)
                            }
                            .padding(.horizontal, 12)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 48)
                            .background(Color.kilalaPaper.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.kilalaBorder, lineWidth: 1)
                            )
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

            // Account Credentials Card
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader("Account Credentials")

                VStack(alignment: .leading, spacing: 16) {
                    // Email
                    VStack(alignment: .leading, spacing: 8) {
                        fieldLabel("Email Address *")
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
                            if isEmailVerified && trimmed != otpEmail.lowercased() {
                                isEmailVerified = false
                            }
                        }
                        .kilalaInputChrome(isFocused: focusedField == .email)
                    }

                    // Password
                    VStack(alignment: .leading, spacing: 8) {
                        fieldLabel("Password *")
                        SecureField("Create a password", text: $password)
                            .font(.kilala(.body))
                            .foregroundColor(.kilalaInk)
                            .tint(.kilalaGreen)
                            .textContentType(.newPassword)
                            .submitLabel(.next)
                            .focused($focusedField, equals: .password)
                            .onSubmit { focusedField = .confirmPassword }
                            .kilalaInputChrome(isFocused: focusedField == .password)

                        VStack(alignment: .leading, spacing: 4) {
                            passwordRuleRow("At least 8 characters", isMet: hasMinLength)
                            passwordRuleRow("At least 1 uppercase letter", isMet: hasUppercase)
                            passwordRuleRow("At least 1 number", isMet: hasNumber)
                            passwordRuleRow("At least 1 special character", isMet: hasSpecialChar)
                        }
                        .padding(.top, 2)
                    }

                    // Confirm Password
                    VStack(alignment: .leading, spacing: 8) {
                        fieldLabel("Confirm Password *")
                        SecureField("Re-enter your password", text: $confirmPassword)
                            .font(.kilala(.body))
                            .foregroundColor(.kilalaInk)
                            .tint(.kilalaGreen)
                            .textContentType(.newPassword)
                            .submitLabel(.done)
                            .focused($focusedField, equals: .confirmPassword)
                            .kilalaInputChrome(isFocused: focusedField == .confirmPassword)

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

            if let accountError {
                inlineErrorBanner(accountError)
            }

            // Primary Continue to Verification Button
            Button(action: handleContinueToVerification) {
                HStack(spacing: 8) {
                    if isSendingOTP {
                        ProgressView()
                            .tint(.white)
                        Text("Sending Verification Code...")
                            .font(.kilala(.headline, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Text("Continue to Verification")
                            .font(.kilala(.headline, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.kilalaGreen)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .disabled(!isStage2Valid || isSendingOTP)
            .opacity((!isStage2Valid || isSendingOTP) ? 0.55 : 1.0)
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

    private func passwordRuleRow(_ text: String, isMet: Bool) -> some View {
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

    // MARK: - Networking & State Transitions

    private func loadLGUs() async {
        isLoadingLGUs = true
        do {
            let fetched = try await APIService.shared.fetchLGUs()
            lgus = fetched
            if selectedLGUId == nil, let first = fetched.first {
                selectedLGUId = first.id
            }
        } catch {
            // Keep lgus empty so user can enter manually or tap Retry
        }
        isLoadingLGUs = false
    }

    private func handleVerifyBusiness() {
        verificationError = nil
        focusedField = nil

        let trimmedName = businessName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPermitNo = businessPermitNo.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTin = tinNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let lguText = resolvedLGUName

        guard !trimmedName.isEmpty, !lguText.isEmpty, !trimmedPermitNo.isEmpty, !trimmedTin.isEmpty else {
            verificationError = "Please fill in your business name, issuing LGU, business permit number, and TIN number."
            return
        }

        isVerifyingBusiness = true

        Task {
            do {
                let response = try await APIService.shared.verifyBusiness(
                    businessName: trimmedName,
                    lgu: lguText,
                    lguId: selectedLGUId,
                    tin: trimmedTin,
                    permitNumber: trimmedPermitNo
                )

                await MainActor.run {
                    self.branchName = response.branchName ?? ""
                    self.businessPermitNo = response.businessPermitNo ?? trimmedPermitNo
                    self.address = response.address ?? ""
                    if let matchedCategory = response.category?.uppercased(),
                       self.categories.contains(matchedCategory) {
                        self.selectedCategory = matchedCategory
                    } else {
                        self.selectedCategory = "OTHER"
                    }
                    self.accountError = nil
                    self.verifiedBusiness = response
                    self.isVerifyingBusiness = false
                }
            } catch {
                await MainActor.run {
                    self.verificationError = error.localizedDescription
                    self.isVerifyingBusiness = false
                }
            }
        }
    }

    private func resetToStage1() {
        focusedField = nil
        verifiedBusiness = nil
        accountError = nil
        verificationError = nil
        isEmailVerified = false
    }

    private func handleContinueToVerification() {
        accountError = nil
        focusedField = nil

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty, trimmedEmail.contains("@"), trimmedEmail.contains(".") else {
            accountError = "Please enter a valid email address."
            return
        }

        guard isPasswordValid else {
            accountError = "Password must meet all requirements."
            return
        }

        guard passwordsMatch else {
            accountError = "Passwords do not match."
            return
        }

        guard !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !businessPermitNo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            accountError = "Please complete all required business profile fields."
            return
        }

        isSendingOTP = true

        Task {
            do {
                try await APIService.shared.requestRegistrationOTP(email: trimmedEmail)
                await MainActor.run {
                    self.otpEmail = trimmedEmail
                    self.isEmailVerified = false
                    self.isSendingOTP = false
                    self.navigateToOTP = true
                }
            } catch {
                await MainActor.run {
                    self.accountError = error.localizedDescription
                    self.isSendingOTP = false
                }
            }
        }
    }

    private func completeBusinessClaim() async throws {
        guard let matched = verifiedBusiness else {
            throw APIError.badRequest("Business verification session expired. Please verify your business again.")
        }

        let trimmedBranch = branchName.trimmingCharacters(in: .whitespacesAndNewlines)
        let response = try await APIService.shared.claimBusiness(
            businessId: matched.businessId,
            email: otpEmail,
            password: password,
            branchName: trimmedBranch.isEmpty ? nil : trimmedBranch,
            category: selectedCategory,
            businessPermitNo: businessPermitNo.trimmingCharacters(in: .whitespacesAndNewlines),
            address: address.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        let loginResponse = LoginResponse(
            message: response.message,
            token: response.token,
            user: response.user
        )

        await MainActor.run {
            onRegistrationSuccess(loginResponse)
        }
    }
}

private extension View {
    func kilalaInputChrome(isFocused: Bool) -> some View {
        self
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(minHeight: 48)
            .background(Color.kilalaPaper.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isFocused ? Color.kilalaGreen : Color.kilalaBorder, lineWidth: isFocused ? 1.5 : 1)
            )
    }
}
