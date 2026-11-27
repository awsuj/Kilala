//
//  BusinessProfileView.swift
//  Kilala
//
//  Created by Joshua Calibo on 11/07/26.
//

import SwiftUI

struct BusinessProfileView: View {
    var token: String
    var userEmail: String?
    var onLogout: (() -> Void)?
    var onProfileUpdated: ((BusinessProfile) -> Void)?

    // Read-only legal & account identifiers
    @State private var businessName: String
    @State private var permitNumber: String
    @State private var tin: String
    @State private var issuingLGU: String
    @State private var isAccredited: Bool
    @State private var accountEmail: String

    // Saved editable details
    @State private var branchName: String
    @State private var category: String
    @State private var address: String

    // Draft editable details used only while isEditing == true
    @State private var isEditing: Bool = false
    @State private var draftBranchName: String = ""
    @State private var draftCategory: String = ""
    @State private var draftAddress: String = ""

    // Loading & alert state
    @State private var isLoadingProfile: Bool = false
    @State private var isSaving: Bool = false
    @State private var showSuccessAlert: Bool = false
    @State private var showEmailSuccessAlert: Bool = false
    @State private var showPasswordSuccessAlert: Bool = false
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""

    private static let validCategories: [String] = [
        "PHARMACY",
        "RESTAURANT",
        "GROCERY",
        "TRANSPORT",
        "MEDICAL",
        "ENTERTAINMENT",
        "OTHER"
    ]

    private var activeToken: String {
        token.isEmpty ? (APIService.shared.authToken ?? "") : token
    }

    private var resolvedEmail: String {
        let local = accountEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        if !local.isEmpty {
            return local
        }
        return (userEmail ?? APIService.shared.currentUserEmail ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSaveChanges: Bool {
        !isSaving &&
        !isLoadingProfile &&
        !draftCategory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !draftAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(
        token: String = APIService.shared.authToken ?? "",
        profile: BusinessProfile? = APIService.shared.currentBusinessProfile,
        userEmail: String? = APIService.shared.currentUserEmail,
        onLogout: (() -> Void)? = nil,
        onProfileUpdated: ((BusinessProfile) -> Void)? = nil
    ) {
        let currentProfile = profile ?? APIService.shared.currentBusinessProfile
        self.token = token
        self.userEmail = userEmail
        self.onLogout = onLogout
        self.onProfileUpdated = onProfileUpdated

        _businessName = State(initialValue: currentProfile?.businessName ?? "")
        _permitNumber = State(initialValue: currentProfile?.businessPermitNo ?? "")
        _tin = State(initialValue: currentProfile?.tinNumber ?? "")
        _issuingLGU = State(initialValue: currentProfile?.lguName ?? "")
        _isAccredited = State(initialValue: currentProfile?.isAccredited ?? true)
        _accountEmail = State(
            initialValue: (userEmail ?? APIService.shared.currentUserEmail ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        )

        _branchName = State(initialValue: currentProfile?.branchName ?? "")
        _category = State(initialValue: currentProfile?.category ?? "OTHER")
        _address = State(initialValue: currentProfile?.address ?? "")
    }

    var body: some View {
        ZStack {
            Color.kilalaPaper
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    // Stacked Mobile Editorial Header (No Top Logout Button)
                    BusinessPortalHeader(
                        title: "Profile",
                    )

                    if isLoadingProfile && businessName.isEmpty {
                        loadingCard
                    } else {
                        profileDetailsCard
                        actionButtonsSection

                        if !isEditing {
                            accountSecuritySection
                                .padding(.top, 8)
                        }
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
            await loadCurrentProfile()
        }
        .alert("Profile Updated", isPresented: $showSuccessAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your business profile details have been updated successfully.")
        }
        .alert("Email Updated", isPresented: $showEmailSuccessAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your account email has been verified and updated successfully.")
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

    // MARK: - Read-Only Identity Card

    private var profileDetailsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Accreditation Status Badge (Icon + Text)
            KilalaStatusBadge(
                icon: isAccredited ? "checkmark.circle.fill" : "xmark.circle.fill",
                label: isAccredited ? "Accredited" : "Inactive",
                foreground: isAccredited ? .kilalaStateValid : .kilalaStateInvalid,
                background: isAccredited
                    ? Color.kilalaStateValid.opacity(0.12)
                    : Color.kilalaStateInvalid.opacity(0.12),
                cornerRadius: 8
            )

            // Business Name
            VStack(alignment: .leading, spacing: 4) {
                fieldLabel("BUSINESS NAME", locked: isEditing)

                Text(businessName.isEmpty ? "Business Profile" : businessName)
                    .font(.kilala(size: 22, weight: .bold, relativeTo: .title2))
                    .foregroundColor(.kilalaInk)
                    .multilineTextAlignment(.leading)
            }

            Divider()
                .overlay(Color.kilalaMintBorder)

            // Editable Business Details
            VStack(alignment: .leading, spacing: 16) {
                if isEditing {
                    editableTextField(
                        label: "BRANCH",
                        placeholder: "Main Branch (Optional)",
                        text: $draftBranchName
                    )

                    editableCategoryField

                    editableTextField(
                        label: "ADDRESS",
                        placeholder: "Business Address",
                        text: $draftAddress,
                        multiline: true
                    )
                } else {
                    detailField(
                        label: "BRANCH",
                        value: branchName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? "Main Branch"
                            : branchName
                    )

                    detailField(
                        label: "CATEGORY",
                        value: formatCategory(category)
                    )

                    detailField(
                        label: "ADDRESS",
                        value: address.isEmpty ? "—" : address
                    )
                }
            }

            Divider()
                .overlay(Color.kilalaMintBorder)

            // Legal & Account Identifiers (Always read-only)
            VStack(alignment: .leading, spacing: 16) {
                detailField(
                    label: "PERMIT NUMBER",
                    value: permitNumber.isEmpty ? "—" : permitNumber,
                    monospaced: true,
                    locked: isEditing
                )

                detailField(
                    label: "TIN",
                    value: tin.isEmpty ? "—" : tin,
                    monospaced: true,
                    locked: isEditing
                )

                detailField(
                    label: "ISSUING LGU",
                    value: issuingLGU.isEmpty ? "—" : issuingLGU,
                    locked: isEditing
                )

                if !resolvedEmail.isEmpty {
                    detailField(
                        label: "ACCOUNT EMAIL",
                        value: resolvedEmail,
                        locked: isEditing
                    )
                }
            }

            if isEditing {
                Text("Legal identifiers are verified by your Issuing LGU and cannot be modified.")
                    .font(.kilala(.footnote))
                    .foregroundColor(.kilalaInkSecondary)
                    .multilineTextAlignment(.leading)
                    .padding(.top, 4)
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
        .animation(.easeInOut(duration: 0.2), value: isEditing)
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
            }
        }
    }

    // MARK: - Account Security Section

    private var accountSecuritySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ACCOUNT SECURITY")
                .font(.kilala(.caption, weight: .bold))
                .tracking(0.8)
                .foregroundColor(.kilalaInkSecondary)

            VStack(spacing: 0) {
                NavigationLink {
                    BusinessChangeEmailView(
                        token: activeToken,
                        currentEmail: resolvedEmail
                    ) { verifiedEmail in
                        accountEmail = verifiedEmail
                        APIService.shared.currentUserEmail = verifiedEmail
                        showEmailSuccessAlert = true
                    }
                } label: {
                    accountSecurityRow(
                        icon: "envelope.fill",
                        title: "Change Email",
                        subtitle: resolvedEmail.isEmpty ? "Update your login email address" : resolvedEmail
                    )
                }
                .buttonStyle(.plain)
                .disabled(isLoadingProfile || isSaving)

                Divider()
                    .overlay(Color.kilalaMintBorder)
                    .padding(.leading, 56)

                NavigationLink {
                    ChangePasswordView(token: activeToken) {
                        showPasswordSuccessAlert = true
                    }
                } label: {
                    accountSecurityRow(
                        icon: "key.fill",
                        title: "Change Password",
                        subtitle: "Update your account password"
                    )
                }
                .buttonStyle(.plain)
                .disabled(isLoadingProfile || isSaving)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.kilalaMintBorder, lineWidth: 1)
            )
        }
    }

    private func accountSecurityRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.kilalaMint)
                    .frame(width: 34, height: 34)

                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.kilalaGreen)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.kilala(.callout, weight: .bold))
                    .foregroundColor(.kilalaInk)

                Text(subtitle)
                    .font(.kilala(.footnote))
                    .foregroundColor(.kilalaInkSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.kilalaInkMuted)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    // MARK: - Loading State

    private var loadingCard: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(.kilalaGreen)
            Text("Loading business profile...")
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
        locked: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            fieldLabel(label, locked: locked)

            Text(value)
                .font(
                    monospaced
                        ? .kilalaMono(.callout, weight: .semibold)
                        : .kilala(.callout, weight: .semibold)
                )
                .foregroundColor(locked ? .kilalaInkSecondary : .kilalaInk)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func editableTextField(
        label: String,
        placeholder: String,
        text: Binding<String>,
        multiline: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel(label)

            Group {
                if multiline {
                    TextField(placeholder, text: text, axis: .vertical)
                        .lineLimit(1...4)
                } else {
                    TextField(placeholder, text: text)
                }
            }
            .font(.kilala(.body))
            .foregroundColor(.kilalaInk)
            .tint(.kilalaGreen)
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

    private var editableCategoryField: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("CATEGORY")

            Menu {
                ForEach(Self.validCategories, id: \.self) { option in
                    Button {
                        draftCategory = option
                    } label: {
                        HStack {
                            Text(formatCategory(option))
                            if draftCategory.uppercased() == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(formatCategory(draftCategory))
                        .font(.kilala(.body))
                        .foregroundColor(.kilalaInk)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.kilalaInkSecondary)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: 48)
                .background(Color.kilalaPaper.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.kilalaBorder, lineWidth: 1)
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Actions & Networking

    private func beginEditing() {
        draftBranchName = branchName
        draftCategory = category.isEmpty ? "OTHER" : category.uppercased()
        draftAddress = address
        withAnimation(.easeInOut(duration: 0.2)) {
            isEditing = true
        }
    }

    private func cancelEditing() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isEditing = false
        }
    }

    private func applyProfile(_ profile: BusinessProfile) {
        businessName = profile.businessName
        permitNumber = profile.businessPermitNo
        tin = profile.tinNumber
        if let lguName = profile.lguName, !lguName.isEmpty {
            issuingLGU = lguName
        }
        isAccredited = profile.isAccredited
        branchName = profile.branchName ?? ""
        category = profile.category
        address = profile.address
    }

    private func loadCurrentProfile() async {
        isLoadingProfile = true
        defer { isLoadingProfile = false }

        do {
            let fetched = try await APIService.shared.fetchBusinessProfile()
            applyProfile(fetched)
            onProfileUpdated?(fetched)
        } catch is CancellationError {
            // Task cancelled
        } catch {
            if businessName.isEmpty {
                errorMessage = error.localizedDescription
                showErrorAlert = true
            }
        }
    }

    private func saveChanges() {
        isSaving = true

        Task {
            do {
                let updated = try await APIService.shared.updateBusinessProfile(
                    branchName: draftBranchName,
                    category: draftCategory,
                    address: draftAddress
                )
                isSaving = false
                applyProfile(updated)
                onProfileUpdated?(updated)
                withAnimation(.easeInOut(duration: 0.2)) {
                    isEditing = false
                }
                showSuccessAlert = true
            } catch {
                isSaving = false
                errorMessage = error.localizedDescription
                showErrorAlert = true
            }
        }
    }

    private func formatCategory(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Other" }
        return trimmed
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}

// MARK: - Business Change Email Flow (Reuses OTPVerificationView)

private struct BusinessChangeEmailView: View {
    var token: String
    let currentEmail: String
    var onSuccess: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var newEmail: String = ""
    @State private var isSendingOTP: Bool = false
    @State private var errorMessage: String? = nil
    @State private var pendingVerificationEmail: String = ""
    @State private var isShowingOTP: Bool = false

    @FocusState private var isEmailFocused: Bool

    private var activeToken: String {
        token.isEmpty ? (APIService.shared.authToken ?? "") : token
    }

    private var trimmedNewEmail: String {
        newEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var canSubmit: Bool {
        !isSendingOTP &&
        !trimmedNewEmail.isEmpty &&
        trimmedNewEmail.contains("@") &&
        trimmedNewEmail.contains(".") &&
        trimmedNewEmail != currentEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var body: some View {
        ZStack {
            Color.kilalaPaper
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Update Account Email")
                            .font(.kilala(size: 22, weight: .bold, relativeTo: .title2))
                            .foregroundColor(.kilalaInk)

                        Text("Enter your new email address. We'll send a 6-digit verification code before updating your account.")
                            .font(.kilala(.subheadline))
                            .foregroundColor(.kilalaInkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        if !currentEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("CURRENT EMAIL")
                                    .font(.kilala(.caption, weight: .bold))
                                    .tracking(0.8)
                                    .foregroundColor(.kilalaInkSecondary)

                                Text(currentEmail)
                                    .font(.kilala(.callout, weight: .semibold))
                                    .foregroundColor(.kilalaInkSecondary)
                            }

                            Divider()
                                .overlay(Color.kilalaMintBorder)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("NEW EMAIL ADDRESS")
                                .font(.kilala(.caption, weight: .bold))
                                .tracking(0.8)
                                .foregroundColor(.kilalaInkSecondary)

                            TextField(
                                "New Email Address",
                                text: $newEmail,
                                prompt: Text(verbatim: "name@example.com").foregroundStyle(Color.kilalaInk.opacity(0.4))
                            )
                            .font(.kilala(.body))
                            .foregroundColor(.kilalaInk)
                            .tint(.kilalaGreen)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                            .focused($isEmailFocused)
                            .onSubmit {
                                if canSubmit {
                                    handleRequestOTP()
                                }
                            }
                            .onChange(of: newEmail) { _, _ in
                                if errorMessage != nil { errorMessage = nil }
                            }
                            .padding(.horizontal, 12)
                            .frame(minHeight: 48)
                            .background(Color.kilalaPaper.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(
                                        isEmailFocused ? Color.kilalaGreen : Color.kilalaBorder,
                                        lineWidth: isEmailFocused ? 1.5 : 1
                                    )
                            )
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

                    if let errorMessage = errorMessage {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.kilalaStateInvalid)
                                .accessibilityHidden(true)

                            Text(errorMessage)
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

                    VStack(spacing: 12) {
                        Button(action: handleRequestOTP) {
                            HStack(spacing: 8) {
                                if isSendingOTP {
                                    ProgressView()
                                        .tint(.white)
                                    Text("Sending Verification Code...")
                                } else {
                                    Text("Send Verification Code")
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
                        .disabled(isSendingOTP)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 96)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle("Change Email")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(Color.kilalaPaper, for: .navigationBar)
        .navigationDestination(isPresented: $isShowingOTP) {
            OTPVerificationView(
                businessEmail: pendingVerificationEmail,
                token: activeToken
            ) { verifiedEmail in
                onSuccess(verifiedEmail)
                dismiss()
            }
        }
    }

    private func handleRequestOTP() {
        isEmailFocused = false
        errorMessage = nil

        let target = trimmedNewEmail
        guard !target.isEmpty, target.contains("@"), target.contains(".") else {
            errorMessage = "Please enter a valid email address."
            return
        }

        if target == currentEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            errorMessage = "New email address must be different from your current email."
            return
        }

        isSendingOTP = true

        Task {
            do {
                try await APIService.shared.requestBusinessEmailChangeOTP(
                    token: activeToken,
                    pendingEmail: target
                )
                await MainActor.run {
                    isSendingOTP = false
                    pendingVerificationEmail = target
                    isShowingOTP = true
                }
            } catch {
                await MainActor.run {
                    isSendingOTP = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
