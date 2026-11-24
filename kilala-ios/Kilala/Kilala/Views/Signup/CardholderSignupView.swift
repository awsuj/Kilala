//
//  CardholderSignupView.swift
//  Kilala
//
//  Created by Eunice Santos on 10/23/26.
//

import SwiftUI

struct CardholderSignupView: View {
    // MARK: - Properties

    var onRegistrationSuccess: ((LoginResponse) -> Void)? = nil

    @State private var privilegeType: PrivilegeType = .pwd
    @State private var cardIdNumber: String = ""
    @State private var firstName: String = ""
    @State private var middleName: String = ""
    @State private var lastName: String = ""
    @State private var dateOfBirth: Date = Date()

    // Backend integration states
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var verifiedProfile: SignupVerificationResponse? = nil
    @State private var isVerified: Bool = false
    @State private var navigateToCreateAccount: Bool = false

    @FocusState private var focusedField: Field?

    enum PrivilegeType: String {
        case pwd = "PWD"
        case seniorCitizen = "SENIOR_CITIZEN"

        var displayName: String {
            switch self {
            case .pwd:
                return "PWD"
            case .seniorCitizen:
                return "Senior Citizen"
            }
        }
    }

    private enum Field: Hashable {
        case firstName
        case middleName
        case lastName
        case cardIdNumber
    }

    private var isFormValid: Bool {
        !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !cardIdNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
                        Text("STEP 1 OF 2 · VERIFY PRIVILEGE CARD")
                            .font(.kilala(.caption, weight: .bold))
                            .tracking(0.8)
                            .foregroundColor(.kilalaGreen)

                        Text("Verify Your LGU Record")
                            .font(.kilala(size: 28, weight: .bold, relativeTo: .title))
                            .foregroundColor(.kilalaInk)

                        Text("Match your official LGU-issued PWD or Senior Citizen record before creating your account.")
                            .font(.kilala(.callout))
                            .foregroundColor(.kilalaInkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 8)

                    // Section 1: ID Type Selection
                    VStack(alignment: .leading, spacing: 8) {
                        sectionHeader("Select Your ID Type")

                        HStack(spacing: 12) {
                            OptionCardView(
                                title: "PWD",
                                icon: "figure.roll",
                                isSelected: privilegeType == .pwd
                            ) {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    privilegeType = .pwd
                                }
                            }

                            OptionCardView(
                                title: "Senior Citizen",
                                icon: "figure.walk",
                                isSelected: privilegeType == .seniorCitizen
                            ) {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    privilegeType = .seniorCitizen
                                }
                            }
                        }
                    }

                    // Section 2: Cardholder Verification Fields
                    VStack(alignment: .leading, spacing: 8) {
                        sectionHeader("Cardholder Details")

                        VStack(alignment: .leading, spacing: 16) {
                            // First Name
                            VStack(alignment: .leading, spacing: 8) {
                                fieldLabel("First Name *")
                                TextField(
                                    "First Name *",
                                    text: $firstName,
                                    prompt: Text("e.g., Juan").foregroundStyle(Color.kilalaInk.opacity(0.4))
                                )
                                .font(.kilala(.body))
                                .foregroundColor(.kilalaInk)
                                .tint(.kilalaGreen)
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled()
                                .submitLabel(.next)
                                .focused($focusedField, equals: .firstName)
                                .onSubmit { focusedField = .middleName }
                                .kilalaCardholderInputChrome(isFocused: focusedField == .firstName)
                            }

                            // Middle Name
                            VStack(alignment: .leading, spacing: 8) {
                                fieldLabel("Middle Name")
                                TextField(
                                    "Middle Name",
                                    text: $middleName,
                                    prompt: Text("Optional").italic().foregroundStyle(Color.kilalaInk.opacity(0.4))
                                )
                                .font(.kilala(.body))
                                .foregroundColor(.kilalaInk)
                                .tint(.kilalaGreen)
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled()
                                .submitLabel(.next)
                                .focused($focusedField, equals: .middleName)
                                .onSubmit { focusedField = .lastName }
                                .kilalaCardholderInputChrome(isFocused: focusedField == .middleName)
                            }

                            // Last Name
                            VStack(alignment: .leading, spacing: 8) {
                                fieldLabel("Last Name *")
                                TextField(
                                    "Last Name *",
                                    text: $lastName,
                                    prompt: Text("e.g., Dela Cruz").foregroundStyle(Color.kilalaInk.opacity(0.4))
                                )
                                .font(.kilala(.body))
                                .foregroundColor(.kilalaInk)
                                .tint(.kilalaGreen)
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled()
                                .submitLabel(.next)
                                .focused($focusedField, equals: .lastName)
                                .onSubmit { focusedField = .cardIdNumber }
                                .kilalaCardholderInputChrome(isFocused: focusedField == .lastName)
                            }

                            // Physical Card Number
                            VStack(alignment: .leading, spacing: 8) {
                                fieldLabel("Physical Card Number *")
                                TextField(
                                    "Physical Card Number *",
                                    text: $cardIdNumber,
                                    prompt: Text(verbatim: "MKT-PWD-2026-00001").foregroundStyle(Color.kilalaInk.opacity(0.4))
                                )
                                .font(.kilalaMono(.body, weight: .medium))
                                .foregroundColor(.kilalaInk)
                                .tint(.kilalaGreen)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                                .submitLabel(.done)
                                .focused($focusedField, equals: .cardIdNumber)
                                .onSubmit { focusedField = nil }
                                .kilalaCardholderInputChrome(isFocused: focusedField == .cardIdNumber)
                            }

                            // Date of Birth
                            VStack(alignment: .leading, spacing: 8) {
                                fieldLabel("Date of Birth *")
                                HStack {
                                    DatePicker(
                                        "Select date",
                                        selection: $dateOfBirth,
                                        displayedComponents: .date
                                    )
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                                    .tint(.kilalaGreen)
                                    .environment(\.locale, Locale(identifier: "en_PH"))

                                    Spacer()

                                    Image(systemName: "calendar")
                                        .font(.system(size: 16, weight: .semibold))
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

                    // Primary Verify Record Button
                    Button(action: handleVerifyRecord) {
                        HStack(spacing: 8) {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                                Text("Verifying Record...")
                                    .font(.kilala(.headline, weight: .bold))
                                    .foregroundColor(.white)
                            } else {
                                Text("Verify Record")
                                    .font(.kilala(.headline, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.kilalaGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .disabled(isLoading)
                    .opacity((!isFormValid || isLoading) ? 0.55 : 1.0)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)

            // Verified Record Modal Overlay
            if isVerified, let profile = verifiedProfile {
                Color.kilalaInk.opacity(0.45)
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.kilalaStateValid.opacity(0.12))
                            .frame(width: 56, height: 56)

                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundColor(.kilalaStateValid)
                            .accessibilityHidden(true)
                    }

                    VStack(spacing: 6) {
                        Text("Record Found!")
                            .font(.kilala(size: 22, weight: .bold, relativeTo: .title2))
                            .foregroundColor(.kilalaInk)

                        Text(
                            [profile.firstName, profile.middleName, profile.lastName]
                                .compactMap { $0 }
                                .filter { !$0.isEmpty }
                                .joined(separator: " ")
                        )
                        .font(.kilala(.callout, weight: .bold))
                        .foregroundColor(.kilalaInk)
                        .multilineTextAlignment(.center)

                        Text("\(privilegeType.displayName) · \(cardIdNumber.trimmingCharacters(in: .whitespacesAndNewlines))")
                            .font(.kilalaMono(.caption, weight: .medium))
                            .foregroundColor(.kilalaInkSecondary)
                            .multilineTextAlignment(.center)
                    }

                    Button(action: {
                        isVerified = false
                        navigateToCreateAccount = true
                    }) {
                        Text("Proceed")
                            .font(.kilala(.headline, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.kilalaGreen)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .padding(.top, 4)
                }
                .padding(24)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.kilalaMintBorder, lineWidth: 1)
                )
                .shadow(color: Color.kilalaInk.opacity(0.18), radius: 16, x: 0, y: 6)
                .padding(.horizontal, 28)
            }
        }
        .navigationTitle("Claim Cardholder ID")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.kilalaPaper, for: .navigationBar)
        .navigationDestination(isPresented: $navigateToCreateAccount) {
            if let profile = verifiedProfile {
                CreateAccountView(
                    profileId: profile.profileId,
                    verifiedFullName: [profile.firstName, profile.middleName, profile.lastName]
                        .compactMap { $0 }
                        .filter { !$0.isEmpty }
                        .joined(separator: " "),
                    verifiedCardNumber: cardIdNumber.trimmingCharacters(in: .whitespacesAndNewlines),
                    verifiedPrivilegeLabel: privilegeType.displayName,
                    onRegistrationSuccess: onRegistrationSuccess
                )
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

    private func handleVerifyRecord() {
        focusedField = nil
        errorMessage = nil
        isVerified = false

        let trimmedFirst = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedMiddle = middleName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLast = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCardId = cardIdNumber.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedFirst.isEmpty, !trimmedLast.isEmpty, !trimmedCardId.isEmpty else {
            errorMessage = "Please fill in your first name, last name, and physical card number."
            return
        }

        isLoading = true

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let formattedDOB = formatter.string(from: dateOfBirth)

        Task {
            do {
                let response = try await APIService.shared.verifyRecord(
                    privilegeType: privilegeType.rawValue,
                    cardIdNumber: trimmedCardId,
                    firstName: trimmedFirst,
                    middleName: trimmedMiddle,
                    lastName: trimmedLast,
                    dateOfBirth: formattedDOB
                )

                await MainActor.run {
                    self.verifiedProfile = response
                    self.isLoading = false
                    self.isVerified = true
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - ID Type Option Card

struct OptionCardView: View {
    var title: String
    var icon: String
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(isSelected ? Color.kilalaGreen.opacity(0.14) : Color.kilalaPaper)
                            .frame(width: 46, height: 46)

                        Image(systemName: icon)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(isSelected ? .kilalaGreen : .kilalaInkSecondary)
                    }

                    Text(title)
                        .font(.kilala(.subheadline, weight: isSelected ? .bold : .semibold))
                        .foregroundColor(isSelected ? .kilalaInk : .kilalaInkSecondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .padding(.horizontal, 12)
                .background(isSelected ? Color.kilalaMint.opacity(0.55) : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            isSelected ? Color.kilalaGreen : Color.kilalaMintBorder,
                            lineWidth: isSelected ? 1.5 : 1
                        )
                )

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.kilalaGreen)
                        .padding(10)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Shared Signup Field Helpers

struct CustomTextField: View {
    @Binding var text: String

    var body: some View {
        TextField("", text: $text)
            .font(.kilala(.body))
            .foregroundColor(.kilalaInk)
            .tint(.kilalaGreen)
            .kilalaCardholderInputChrome(isFocused: false)
    }
}

extension View {
    func kilalaCardholderInputChrome(isFocused: Bool) -> some View {
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

struct CardholderSignupView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            CardholderSignupView()
        }
    }
}
