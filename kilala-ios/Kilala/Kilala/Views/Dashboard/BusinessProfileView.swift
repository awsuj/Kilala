//
//  BusinessProfileView.swift
//  Kilala
//
//  Created by Joshua Calibo on 11/07/26.
//

import SwiftUI

struct BusinessProfileView: View {
    var userEmail: String?
    var onLogout: (() -> Void)?
    var onProfileUpdated: ((BusinessProfile) -> Void)?

    // Read-only legal & account identifiers
    @State private var businessName: String
    @State private var permitNumber: String
    @State private var tin: String
    @State private var issuingLGU: String
    @State private var isAccredited: Bool

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
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""

    private static let darkGreenText = Color(red: 0.09, green: 0.48, blue: 0.22)
    private static let darkRedText = Color(red: 0.72, green: 0.14, blue: 0.14)

    private static let validCategories: [String] = [
        "PHARMACY",
        "RESTAURANT",
        "GROCERY",
        "TRANSPORT",
        "MEDICAL",
        "ENTERTAINMENT",
        "OTHER"
    ]

    private var resolvedEmail: String {
        let candidate = (userEmail ?? APIService.shared.currentUserEmail ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return candidate
    }

    private var canSaveChanges: Bool {
        !isSaving &&
        !isLoadingProfile &&
        !draftCategory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !draftAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(
        profile: BusinessProfile? = APIService.shared.currentBusinessProfile,
        userEmail: String? = APIService.shared.currentUserEmail,
        onLogout: (() -> Void)? = nil,
        onProfileUpdated: ((BusinessProfile) -> Void)? = nil
    ) {
        let currentProfile = profile ?? APIService.shared.currentBusinessProfile
        self.userEmail = userEmail
        self.onLogout = onLogout
        self.onProfileUpdated = onProfileUpdated

        _businessName = State(initialValue: currentProfile?.businessName ?? "")
        _permitNumber = State(initialValue: currentProfile?.businessPermitNo ?? "")
        _tin = State(initialValue: currentProfile?.tinNumber ?? "")
        _issuingLGU = State(initialValue: currentProfile?.lguName ?? "")
        _isAccredited = State(initialValue: currentProfile?.isAccredited ?? true)

        _branchName = State(initialValue: currentProfile?.branchName ?? "")
        _category = State(initialValue: currentProfile?.category ?? "OTHER")
        _address = State(initialValue: currentProfile?.address ?? "")
    }

    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 22) {
                    if isLoadingProfile && businessName.isEmpty {
                        loadingCard
                    } else {
                        profileDetailsCard
                        actionButtonsSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 112)
            }
            .refreshable {
                if !isEditing {
                    await loadCurrentProfile()
                }
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let onLogout = onLogout {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Logout", action: onLogout)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                }
            }
        }
        .task {
            await loadCurrentProfile()
        }
        .alert("Profile Updated", isPresented: $showSuccessAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your business profile details have been updated successfully.")
        }
        .alert("Update Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Centered Profile Card

    private var profileDetailsCard: some View {
        VStack(spacing: 18) {
            // Soft Pastel Accreditation Status Pill
            Text(isAccredited ? "Accredited" : "Inactive")
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    isAccredited
                        ? Color.green.opacity(0.15)
                        : Color.red.opacity(0.15)
                )
                .foregroundColor(isAccredited ? Self.darkGreenText : Self.darkRedText)
                .clipShape(Capsule())

            // Business Name Hero Header (Centered)
            VStack(spacing: 6) {
                centeredLabel("BUSINESS NAME", locked: isEditing)

                Text(businessName.isEmpty ? "Business Profile" : businessName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
            }

            Divider()
                .overlay(Color.gray.opacity(0.20))

            // Editable Business Details (Read-only centered values by default, centered white inputs in edit mode)
            VStack(spacing: 16) {
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
                    centeredDetailField(
                        label: "BRANCH",
                        value: branchName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? "Main Branch"
                            : branchName
                    )

                    centeredDetailField(
                        label: "CATEGORY",
                        value: formatCategory(category)
                    )

                    centeredDetailField(
                        label: "ADDRESS",
                        value: address.isEmpty ? "—" : address
                    )
                }
            }

            Divider()
                .overlay(Color.gray.opacity(0.20))

            // Legal & Account Identifiers (Always centered & read-only)
            VStack(spacing: 16) {
                centeredDetailField(
                    label: "PERMIT NUMBER",
                    value: permitNumber.isEmpty ? "—" : permitNumber,
                    monospaced: true,
                    locked: isEditing
                )

                centeredDetailField(
                    label: "TIN",
                    value: tin.isEmpty ? "—" : tin,
                    monospaced: true,
                    locked: isEditing
                )

                centeredDetailField(
                    label: "ISSUING LGU",
                    value: issuingLGU.isEmpty ? "—" : issuingLGU,
                    locked: isEditing
                )

                if !resolvedEmail.isEmpty {
                    centeredDetailField(
                        label: "EMAIL",
                        value: resolvedEmail,
                        locked: isEditing
                    )
                }
            }

            if isEditing {
                Text("Legal identifiers are verified by your Issuing LGU and cannot be modified.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 26)
        .padding(.horizontal, 22)
        .frame(maxWidth: .infinity)
        .background(Color(white: 0.96))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.gray.opacity(0.25), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.2), value: isEditing)
    }

    // MARK: - Pill Action Buttons

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
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(canSaveChanges ? Color.black : Color.gray.opacity(0.45))
                        .clipShape(Capsule())
                        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
                    }
                    .disabled(!canSaveChanges)

                    Button(action: cancelEditing) {
                        Text("Cancel")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                    }
                    .disabled(isSaving)
                }
            } else {
                Button(action: beginEditing) {
                    HStack(spacing: 8) {
                        Image(systemName: "pencil")
                            .font(.subheadline.weight(.semibold))
                        Text("Update details")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
                }
                .disabled(isLoadingProfile)
            }
        }
    }

    // MARK: - Loading State

    private var loadingCard: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading business profile...")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .background(Color(white: 0.96))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.gray.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Field Components

    private func centeredLabel(_ title: String, locked: Bool = false) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .fontWeight(.bold)
                .tracking(0.8)
                .foregroundColor(.gray)

            if locked {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                    .foregroundColor(.gray.opacity(0.8))
            }
        }
    }

    private func centeredDetailField(
        label: String,
        value: String,
        monospaced: Bool = false,
        locked: Bool = false
    ) -> some View {
        VStack(spacing: 4) {
            centeredLabel(label, locked: locked)

            Text(value)
                .font(monospaced ? .system(.subheadline, design: .monospaced).weight(.semibold) : .subheadline.weight(.semibold))
                .foregroundColor(locked ? Color(white: 0.38) : .black)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    private func editableTextField(
        label: String,
        placeholder: String,
        text: Binding<String>,
        multiline: Bool = false
    ) -> some View {
        VStack(spacing: 6) {
            centeredLabel(label)

            Group {
                if multiline {
                    TextField(placeholder, text: text, axis: .vertical)
                        .lineLimit(1...4)
                } else {
                    TextField(placeholder, text: text)
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.black)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.gray.opacity(0.28), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
        .frame(maxWidth: .infinity)
    }

    private var editableCategoryField: some View {
        VStack(spacing: 6) {
            centeredLabel("CATEGORY")

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
                HStack(spacing: 6) {
                    Spacer(minLength: 16)
                    Text(formatCategory(draftCategory))
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.black)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.gray)
                    Spacer(minLength: 16)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.gray.opacity(0.28), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
            }
        }
        .frame(maxWidth: .infinity)
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
