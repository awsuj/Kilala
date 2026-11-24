//
//  CardholderProfileView.swift
//  Kilala
//
//  Created by Eunice Santos on 11/24/26.
//

import SwiftUI
import UIKit

struct CardholderProfileView: View {
    // MARK: - Properties

    var token: String
    var userEmail: String?
    var onLogout: (() -> Void)?
    var onProfileUpdated: ((CardholderProfile) -> Void)?

    // Read-only identity & LGU credentials
    @State private var firstName: String
    @State private var middleName: String
    @State private var lastName: String
    @State private var status: String
    @State private var photoURL: String
    @State private var privilegeType: String
    @State private var disabilityType: String
    @State private var issuingLGU: String
    @State private var issueDate: String
    @State private var expiryDate: String
    @State private var dateOfBirth: String
    @State private var address: String

    // Saved editable contact & account details
    @State private var emergencyContactName: String
    @State private var emergencyContactNumber: String
    @State private var email: String

    // Draft editable details used only while isEditing == true
    @State private var isEditing: Bool = false
    @State private var draftEmergencyContactName: String = ""
    @State private var draftEmergencyContactNumber: String = ""
    @State private var draftEmail: String = ""

    // Email change OTP verification navigation state
    @State private var isShowingEmailOTP: Bool = false
    @State private var pendingVerificationEmail: String = ""
    @State private var didCompleteEmailOTPVerification: Bool = false

    // Loading & alert state
    @State private var isLoadingProfile: Bool = false
    @State private var isSaving: Bool = false
    @State private var showSuccessAlert: Bool = false
    @State private var showPasswordSuccessAlert: Bool = false
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""

    private static let avatarSize: CGFloat = 88
    private static let avatarHalfHeight: CGFloat = 44
    private static let emptyEmergencyContactText = "No emergency contact set"

    // MARK: - Computed Properties

    private var activeToken: String {
        token.isEmpty ? (APIService.shared.authToken ?? "") : token
    }

    private var fullName: String {
        [firstName, middleName, lastName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private var isPWD: Bool {
        privilegeType.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == "PWD"
    }

    private var formattedPrivilegeType: String {
        switch privilegeType.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
        case "PWD":
            return "PWD"
        case "SENIOR_CITIZEN":
            return "Senior Citizen"
        default:
            let trimmed = privilegeType.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "—" : trimmed
        }
    }

    private var formattedIssueAndExpiryDate: String {
        let formattedIssue = formatDisplayDate(issueDate, emptyFallback: "—")
        let trimmedExpiry = expiryDate.trimmingCharacters(in: .whitespacesAndNewlines)
        let formattedExpiry = trimmedExpiry.isEmpty
            ? (isPWD ? "—" : "Lifetime")
            : formatDisplayDate(trimmedExpiry, emptyFallback: "—")
        return "\(formattedIssue) / \(formattedExpiry)"
    }

    private var formattedEmergencyContactNumberForDisplay: String {
        let digits = extractLocalMobileDigits(from: emergencyContactNumber)
        guard !digits.isEmpty else { return "" }
        return "+63 \(formatLocalMobileDigits(digits))"
    }

    private var draftEmergencyContactDigits: String {
        extractLocalMobileDigits(from: draftEmergencyContactNumber)
    }

    private var hasIncompleteEmergencyContactNumber: Bool {
        !draftEmergencyContactDigits.isEmpty && draftEmergencyContactDigits.count < 10
    }

    private var statusBadgeAppearance: (icon: String, label: String, foreground: Color, background: Color) {
        let normalized = status.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        switch normalized {
        case "ACTIVE":
            return (
                "checkmark.circle.fill",
                "ACTIVE",
                .kilalaStateValid,
                Color.kilalaStateValid.opacity(0.12)
            )
        case "EXPIRED":
            return (
                "clock.badge.exclamationmark.fill",
                "EXPIRED",
                .kilalaInk,
                Color.kilalaStateExpired.opacity(0.28)
            )
        case "REVOKED", "SUSPENDED":
            return (
                "xmark.circle.fill",
                normalized,
                .kilalaStateInvalid,
                Color.kilalaStateInvalid.opacity(0.12)
            )
        default:
            let label = normalized.isEmpty ? "ACTIVE" : normalized
            return (
                "checkmark.circle.fill",
                label,
                .kilalaStateValid,
                Color.kilalaStateValid.opacity(0.12)
            )
        }
    }

    private var canSaveChanges: Bool {
        !isSaving &&
        !isLoadingProfile &&
        !draftEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !hasIncompleteEmergencyContactNumber
    }

    // MARK: - Initialization

    init(
        token: String = APIService.shared.authToken ?? "",
        profile: CardholderProfile? = APIService.shared.currentCardholderProfile,
        userEmail: String? = APIService.shared.currentUserEmail,
        onLogout: (() -> Void)? = nil,
        onProfileUpdated: ((CardholderProfile) -> Void)? = nil
    ) {
        let currentProfile = profile ?? APIService.shared.currentCardholderProfile
        self.token = token
        self.userEmail = userEmail
        self.onLogout = onLogout
        self.onProfileUpdated = onProfileUpdated

        _firstName = State(initialValue: currentProfile?.firstName ?? "")
        _middleName = State(initialValue: currentProfile?.middleName ?? "")
        _lastName = State(initialValue: currentProfile?.lastName ?? "")
        _status = State(initialValue: currentProfile?.status ?? "ACTIVE")
        _photoURL = State(initialValue: currentProfile?.resolvedPhotoURL ?? "")
        _privilegeType = State(initialValue: currentProfile?.privilegeType ?? "")
        _disabilityType = State(initialValue: currentProfile?.disabilityType ?? "")
        _issuingLGU = State(initialValue: currentProfile?.resolvedIssuingLGU ?? "")
        _issueDate = State(initialValue: currentProfile?.resolvedIssueDate ?? "")
        _expiryDate = State(initialValue: currentProfile?.expiryDate ?? "")
        _dateOfBirth = State(initialValue: currentProfile?.dateOfBirth ?? "")
        _address = State(initialValue: currentProfile?.address ?? "")

        _emergencyContactName = State(initialValue: currentProfile?.emergencyContactName ?? "")
        _emergencyContactNumber = State(initialValue: currentProfile?.resolvedEmergencyContactNumber ?? "")
        _email = State(
            initialValue: currentProfile?.email
                ?? userEmail
                ?? APIService.shared.currentUserEmail
                ?? ""
        )
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.kilalaPaper
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    // Stacked Mobile Editorial Header (No Top Logout Button)
                    BusinessPortalHeader(
                        title: "Profile"
                    )

                    if isLoadingProfile && firstName.isEmpty {
                        loadingCard
                    } else {
                        profileDetailsCard
                        actionButtonsSection
                    }

                    // Relocated Full-Width Log Out Button (24pt XL section gap)
                    if let onLogout = onLogout {
                        Button(action: onLogout) {
                            HStack(spacing: 8) {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 16, weight: .semibold))
                                    .accessibilityHidden(true)

                                Text("Log Out")
                                    .font(.kilala(.callout, weight: .bold))
                            }
                            .foregroundColor(.kilalaStateInvalid)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.kilalaStateInvalid.opacity(0.45), lineWidth: 1)
                            )
                        }
                        .disabled(isSaving)
                        .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 96)
            }
            .scrollDismissesKeyboard(.interactively)
            .refreshable {
                if !isEditing {
                    await loadCurrentProfile()
                }
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if !isShowingEmailOTP {
                await loadCurrentProfile()
            }
        }
        .navigationDestination(isPresented: $isShowingEmailOTP) {
            OTPVerificationView(
                email: pendingVerificationEmail,
                token: activeToken,
                onProfileVerified: { verifiedProfile in
                    didCompleteEmailOTPVerification = true
                    applyProfile(verifiedProfile)
                    onProfileUpdated?(verifiedProfile)
                },
                onVerified: { verifiedEmail in
                    didCompleteEmailOTPVerification = true
                    email = verifiedEmail
                    draftEmail = verifiedEmail
                    pendingVerificationEmail = ""
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isEditing = false
                    }
                    showSuccessAlert = true
                }
            )
        }
        .onChange(of: isShowingEmailOTP) { _, isPresented in
            if !isPresented && !didCompleteEmailOTPVerification {
                // Retain the existing verified email if the user cancelled or navigated back
                draftEmail = email
                pendingVerificationEmail = ""
                withAnimation(.easeInOut(duration: 0.2)) {
                    isEditing = false
                }
            }
        }
        .alert("Profile Updated", isPresented: $showSuccessAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your cardholder profile details have been updated successfully.")
        }
        .alert("Password Updated", isPresented: $showPasswordSuccessAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your account password has been changed successfully.")
        }
        .alert("Update Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Profile Card with Top-Border Centered Profile Picture

    private var profileDetailsCard: some View {
        ZStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 16) {
                headerIdentitySection

                Divider()
                    .overlay(Color.kilalaMintBorder)

                privilegeCredentialsSection

                Divider()
                    .overlay(Color.kilalaMintBorder)

                personalDetailsSection

                Divider()
                    .overlay(Color.kilalaMintBorder)

                editableContactAndAccountSection

                if isEditing {
                    Text("Identity and privilege details are verified by your Issuing LGU and cannot be modified.")
                        .font(.kilala(.footnote))
                        .foregroundColor(.kilalaInkSecondary)
                        .multilineTextAlignment(.leading)
                        .padding(.top, 4)
                }
            }
            .padding(.top, Self.avatarHalfHeight + 16)
            .padding(.bottom, 20)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.kilalaMintBorder, lineWidth: 1)
            )
            .padding(.top, Self.avatarHalfHeight)

            // Centered non-editable profile picture on the top border of the profile card
            profileAvatarView
        }
        .animation(.easeInOut(duration: 0.2), value: isEditing)
    }

    // MARK: - Top Header (Profile Picture, Status Badge & Cardholder Name)

    private var profileAvatarView: some View {
        ZStack {
            if let base64Image = decodeBase64Image(from: photoURL) {
                Image(uiImage: base64Image)
                    .resizable()
                    .scaledToFill()
            } else if let url = validPhotoURL(from: photoURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        defaultProfileAvatarPlaceholder
                    }
                }
            } else {
                defaultProfileAvatarPlaceholder
            }
        }
        .frame(width: Self.avatarSize, height: Self.avatarSize)
        .clipShape(Circle())
        .background(
            Circle()
                .fill(Color.white)
                .frame(width: Self.avatarSize + 6, height: Self.avatarSize + 6)
        )
        .overlay(
            Circle()
                .stroke(Color.kilalaMintBorder, lineWidth: 1.5)
                .frame(width: Self.avatarSize + 6, height: Self.avatarSize + 6)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Cardholder profile photo")
    }

    private var defaultProfileAvatarPlaceholder: some View {
        ZStack {
            Circle()
                .fill(Color.kilalaMint)

            Image(systemName: "person.fill")
                .font(.system(size: 36, weight: .semibold))
                .foregroundColor(.kilalaGreen)
        }
    }

    private var headerIdentitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Cardholder Status Badge (Directly below profile picture and above the name)
            KilalaStatusBadge(
                icon: statusBadgeAppearance.icon,
                label: statusBadgeAppearance.label,
                foreground: statusBadgeAppearance.foreground,
                background: statusBadgeAppearance.background,
                cornerRadius: 8
            )

            // Cardholder Full Name (First Name, Middle Name, Last Name — non-editable)
            VStack(alignment: .leading, spacing: 4) {
                fieldLabel("CARDHOLDER NAME", locked: isEditing)

                Text(fullName.isEmpty ? "Cardholder Profile" : fullName)
                    .font(.kilala(size: 22, weight: .bold, relativeTo: .title2))
                    .foregroundColor(.kilalaInk)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Profile Details Sections

    private var privilegeCredentialsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            detailField(
                label: "PRIVILEGE TYPE",
                value: formattedPrivilegeType,
                locked: isEditing
            )

            if isPWD {
                detailField(
                    label: "DISABILITY TYPE",
                    value: disabilityType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? "—"
                        : disabilityType,
                    locked: isEditing
                )
            }

            detailField(
                label: "ISSUING LGU",
                value: issuingLGU.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "—"
                    : issuingLGU,
                locked: isEditing
            )

            detailField(
                label: "ISSUE DATE / EXPIRY DATE",
                value: formattedIssueAndExpiryDate,
                locked: isEditing
            )
        }
    }

    private var personalDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            detailField(
                label: "DATE OF BIRTH",
                value: formatDisplayDate(dateOfBirth, emptyFallback: "—"),
                locked: isEditing
            )

            detailField(
                label: "ADDRESS",
                value: address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "—"
                    : address,
                locked: isEditing
            )
        }
    }

    private var editableContactAndAccountSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if isEditing {
                editableTextField(
                    label: "EMERGENCY CONTACT NAME",
                    placeholder: "Full name of emergency contact",
                    text: $draftEmergencyContactName
                )

                editableEmergencyPhoneField

                editableTextField(
                    label: "EMAIL",
                    placeholder: "name@example.com",
                    text: $draftEmail,
                    keyboardType: .emailAddress,
                    autocapitalization: .never
                )
            } else {
                let trimmedContactName = emergencyContactName.trimmingCharacters(in: .whitespacesAndNewlines)
                let displayContactNumber = formattedEmergencyContactNumberForDisplay
                let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

                detailField(
                    label: "EMERGENCY CONTACT NAME",
                    value: trimmedContactName.isEmpty
                        ? Self.emptyEmergencyContactText
                        : trimmedContactName,
                    isMutedValue: trimmedContactName.isEmpty
                )

                detailField(
                    label: "EMERGENCY CONTACT NUMBER",
                    value: displayContactNumber.isEmpty
                        ? Self.emptyEmergencyContactText
                        : displayContactNumber,
                    isMutedValue: displayContactNumber.isEmpty
                )

                detailField(
                    label: "EMAIL",
                    value: trimmedEmail.isEmpty ? "—" : trimmedEmail
                )
            }
        }
    }

    // MARK: - Edit Mode Action Buttons (12pt Radius)

    private var actionButtonsSection: some View {
        Group {
            if isEditing {
                VStack(spacing: 12) {
                    Button(action: saveChanges) {
                        HStack(spacing: 8) {
                            if isSaving {
                                ProgressView()
                                    .tint(.white)
                                Text("Saving Changes...")
                            } else {
                                Text("Save Changes")
                            }
                        }
                        .font(.kilala(.callout, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(canSaveChanges ? Color.kilalaGreen : Color.kilalaInkMuted)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .disabled(!canSaveChanges)

                    Button(action: cancelEditing) {
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
                    .disabled(isSaving)
                }
            } else {
                VStack(spacing: 12) {
                    Button(action: beginEditing) {
                        HStack(spacing: 8) {
                            Image(systemName: "pencil")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .accessibilityHidden(true)

                            Text("Update details")
                                .font(.kilala(.callout, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.kilalaGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .disabled(isLoadingProfile)

                    NavigationLink {
                        ChangePasswordView(token: activeToken) {
                            showPasswordSuccessAlert = true
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "key.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .accessibilityHidden(true)

                            Text("Change password")
                                .font(.kilala(.callout, weight: .bold))
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
                    .disabled(isLoadingProfile)
                }
            }
        }
    }

    // MARK: - Loading State

    private var loadingCard: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(.kilalaGreen)
            Text("Loading cardholder profile...")
                .font(.kilala(.callout))
                .foregroundColor(.kilalaInkSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, 16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.kilalaMintBorder, lineWidth: 1)
        )
    }

    // MARK: - Field Components

    private func fieldLabel(_ title: String, locked: Bool = false) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.kilala(.caption, weight: .bold))
                .tracking(0.8)
                .foregroundColor(.kilalaInkSecondary)

            if locked {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                    .foregroundColor(.kilalaInkMuted)
                    .accessibilityHidden(true)
            }
        }
    }

    private func detailField(
        label: String,
        value: String,
        monospaced: Bool = false,
        locked: Bool = false,
        isMutedValue: Bool = false
    ) -> some View {
        let valueForeground: Color = {
            if isMutedValue || locked {
                return .kilalaInkSecondary
            }
            return .kilalaInk
        }()

        let valueFont: Font = {
            if monospaced {
                return .kilalaMono(.callout, weight: .semibold)
            }
            return .kilala(.callout, weight: isMutedValue ? .regular : .semibold)
        }()

        return VStack(alignment: .leading, spacing: 4) {
            fieldLabel(label, locked: locked)

            Text(value)
                .font(valueFont)
                .italic(isMutedValue)
                .foregroundColor(valueForeground)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var editableEmergencyPhoneField: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("EMERGENCY CONTACT NUMBER")

            HStack(spacing: 10) {
                Text("+63")
                    .font(.kilala(.body))
                    .foregroundColor(.kilalaInk)
                    .fixedSize()

                Rectangle()
                    .fill(Color.kilalaBorder)
                    .frame(width: 1, height: 22)
                    .accessibilityHidden(true)

                TextField(
                    "xxx xxx xxxx",
                    text: $draftEmergencyContactNumber,
                    prompt: Text(verbatim: "xxx xxx xxxx").foregroundStyle(Color.kilalaInk.opacity(0.4))
                )
                .font(.kilala(.body))
                .foregroundColor(.kilalaInk)
                .tint(.kilalaGreen)
                .keyboardType(.numberPad)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .multilineTextAlignment(.leading)
                .onChange(of: draftEmergencyContactNumber) { _, newValue in
                    let normalizedDigits = extractLocalMobileDigits(from: newValue)
                    let formatted = formatLocalMobileDigits(normalizedDigits)
                    if formatted != newValue {
                        draftEmergencyContactNumber = formatted
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 48)
            .background(Color.kilalaPaper.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        hasIncompleteEmergencyContactNumber
                            ? Color.kilalaStateInvalid.opacity(0.65)
                            : Color.kilalaBorder,
                        lineWidth: 1
                    )
            )

            if hasIncompleteEmergencyContactNumber {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.kilalaStateInvalid)
                        .accessibilityHidden(true)

                    Text("Please enter a valid 10-digit mobile number.")
                        .font(.kilala(.caption, weight: .semibold))
                        .foregroundColor(.kilalaStateInvalid)
                }
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func editableTextField(
        label: String,
        placeholder: String,
        text: Binding<String>,
        keyboardType: UIKeyboardType = .default,
        autocapitalization: TextInputAutocapitalization = .words
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel(label)

            TextField(placeholder, text: text)
                .font(.kilala(.body))
                .foregroundColor(.kilalaInk)
                .tint(.kilalaGreen)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(autocapitalization)
                .autocorrectionDisabled()
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: 48)
                .background(Color.kilalaPaper.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.kilalaBorder, lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Helper Methods

    /// Extracts the 10-digit Philippine subscriber number after `+63` (or `63` / leading `0`),
    /// stripping all non-digit characters and capping at 10 digits.
    private func extractLocalMobileDigits(from raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        var digits = String(trimmed.filter(\.isNumber))

        if trimmed.hasPrefix("+63") && digits.hasPrefix("63") {
            digits = String(digits.dropFirst(2))
        } else if digits.count == 12 && digits.hasPrefix("63") {
            digits = String(digits.dropFirst(2))
        } else if digits.count == 11 && digits.hasPrefix("0") {
            digits = String(digits.dropFirst(1))
        }

        if digits.count > 10 {
            digits = String(digits.prefix(10))
        }

        return digits
    }

    /// Formats up to 10 digits into the `xxx xxx xxxx` spacing pattern.
    private func formatLocalMobileDigits(_ rawDigits: String) -> String {
        let digits = String(rawDigits.filter(\.isNumber).prefix(10))
        guard !digits.isEmpty else { return "" }

        let firstGroup = String(digits.prefix(3))
        if digits.count <= 3 {
            return firstGroup
        }

        let secondGroup = String(digits.dropFirst(3).prefix(3))
        if digits.count <= 6 {
            return "\(firstGroup) \(secondGroup)"
        }

        let thirdGroup = String(digits.dropFirst(6).prefix(4))
        return "\(firstGroup) \(secondGroup) \(thirdGroup)"
    }

    private func validPhotoURL(from raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !trimmed.lowercased().hasPrefix("data:image"),
              let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return nil
        }
        return url
    }

    private func decodeBase64Image(from raw: String) -> UIImage? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.lowercased().hasPrefix("data:image"),
              let commaIndex = trimmed.firstIndex(of: ",") else {
            return nil
        }
        let base64Substring = String(trimmed[trimmed.index(after: commaIndex)...])
        guard let imageData = Data(base64Encoded: base64Substring, options: .ignoreUnknownCharacters) else {
            return nil
        }
        return UIImage(data: imageData)
    }

    private func formatDisplayDate(_ raw: String, emptyFallback: String = "—") -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return emptyFallback }

        let displayFormatter = DateFormatter()
        displayFormatter.locale = Locale(identifier: "en_US_POSIX")
        displayFormatter.dateFormat = "MMM d, yyyy"

        if let isoDate = TransactionDateFormatting.parse(trimmed) {
            return displayFormatter.string(from: isoDate)
        }

        let shortISOFormatter = DateFormatter()
        shortISOFormatter.locale = Locale(identifier: "en_US_POSIX")
        shortISOFormatter.dateFormat = "yyyy-MM-dd"

        let datePrefix = String(trimmed.prefix(10))
        if let parsedShort = shortISOFormatter.date(from: datePrefix) {
            return displayFormatter.string(from: parsedShort)
        }

        return trimmed
    }

    private func applyProfile(_ profile: CardholderProfile) {
        firstName = profile.firstName
        middleName = profile.middleName ?? ""
        lastName = profile.lastName
        status = profile.status
        photoURL = profile.resolvedPhotoURL ?? ""
        privilegeType = profile.privilegeType
        disabilityType = profile.disabilityType ?? ""
        issuingLGU = profile.resolvedIssuingLGU
        issueDate = profile.resolvedIssueDate ?? ""
        expiryDate = profile.expiryDate ?? ""
        dateOfBirth = profile.dateOfBirth
        address = profile.address

        emergencyContactName = profile.emergencyContactName ?? ""
        let contactDigits = extractLocalMobileDigits(from: profile.resolvedEmergencyContactNumber)
        emergencyContactNumber = contactDigits.count == 10
            ? "+63\(contactDigits)"
            : profile.resolvedEmergencyContactNumber

        if let profileEmail = profile.email,
           !profileEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            email = profileEmail
        } else if email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            email = userEmail ?? APIService.shared.currentUserEmail ?? ""
        }
    }

    // MARK: - Actions & Networking

    private func beginEditing() {
        draftEmergencyContactName = emergencyContactName.trimmingCharacters(in: .whitespacesAndNewlines)
        let existingDigits = extractLocalMobileDigits(from: emergencyContactNumber)
        draftEmergencyContactNumber = formatLocalMobileDigits(existingDigits)
        draftEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        withAnimation(.easeInOut(duration: 0.2)) {
            isEditing = true
        }
    }

    private func cancelEditing() {
        draftEmergencyContactName = emergencyContactName
        let existingDigits = extractLocalMobileDigits(from: emergencyContactNumber)
        draftEmergencyContactNumber = formatLocalMobileDigits(existingDigits)
        draftEmail = email
        withAnimation(.easeInOut(duration: 0.2)) {
            isEditing = false
        }
    }

    private func loadCurrentProfile() async {
        isLoadingProfile = true
        defer { isLoadingProfile = false }

        do {
            let fetched = try await APIService.shared.getCardholderProfile(token: activeToken)
            applyProfile(fetched)
            onProfileUpdated?(fetched)
        } catch is CancellationError {
            // Task cancelled
        } catch {
            if firstName.isEmpty {
                errorMessage = error.localizedDescription
                showErrorAlert = true
            }
        }
    }

    private func saveChanges() {
        let trimmedEmail = draftEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmedEmail.isEmpty, trimmedEmail.contains("@"), trimmedEmail.contains(".") else {
            errorMessage = "Please enter a valid email address."
            showErrorAlert = true
            return
        }

        let contactDigits = draftEmergencyContactDigits
        guard contactDigits.isEmpty || contactDigits.count == 10 else {
            errorMessage = "Please enter a valid 10-digit mobile number."
            showErrorAlert = true
            return
        }

        let formattedEmergencyContactPayload = contactDigits.isEmpty ? "" : "+63\(contactDigits)"
        let currentVerifiedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        isSaving = true

        Task {
            do {
                let updated = try await APIService.shared.updateCardholderProfile(
                    token: activeToken,
                    email: trimmedEmail,
                    emergencyContactName: draftEmergencyContactName,
                    emergencyContactNumber: formattedEmergencyContactPayload
                )
                await MainActor.run {
                    isSaving = false
                    applyProfile(updated)
                    onProfileUpdated?(updated)

                    let needsEmailOTP =
                        (updated.requiresEmailVerification == true) ||
                        (trimmedEmail != currentVerifiedEmail)

                    if needsEmailOTP {
                        pendingVerificationEmail = updated.pendingEmail ?? trimmedEmail
                        didCompleteEmailOTPVerification = false
                        isShowingEmailOTP = true
                    } else {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isEditing = false
                        }
                        showSuccessAlert = true
                    }
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                    showErrorAlert = true
                }
            }
        }
    }
}
