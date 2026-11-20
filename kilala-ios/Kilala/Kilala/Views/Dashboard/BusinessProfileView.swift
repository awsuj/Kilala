//
//  BusinessProfileView.swift
//  Kilala
//
//  Created by Joshua Calibo on 11/07/26.
//

import SwiftUI

struct BusinessProfileView: View {
    var onProfileUpdated: ((BusinessProfile) -> Void)?
    
    // Read-only legal identifiers initialized from the current session's data
    @State private var businessName: String
    @State private var permitNumber: String
    @State private var tin: String
    @State private var issuingLGU: String
    
    // Editable details bound to active TextFields, initialized from the current session's data
    @State private var branchName: String
    @State private var category: String
    @State private var address: String
    
    // Loading & alert state
    @State private var isLoadingProfile: Bool = false
    @State private var isSaving: Bool = false
    @State private var showSuccessAlert: Bool = false
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    
    init(
        profile: BusinessProfile? = APIService.shared.currentBusinessProfile,
        onProfileUpdated: ((BusinessProfile) -> Void)? = nil
    ) {
        let currentProfile = profile ?? APIService.shared.currentBusinessProfile
        self.onProfileUpdated = onProfileUpdated
        
        _businessName = State(initialValue: currentProfile?.businessName ?? "")
        _permitNumber = State(initialValue: currentProfile?.businessPermitNo ?? "")
        _tin = State(initialValue: currentProfile?.tinNumber ?? "")
        _issuingLGU = State(initialValue: currentProfile?.lguName ?? "")
        
        _branchName = State(initialValue: currentProfile?.branchName ?? "")
        _category = State(initialValue: currentProfile?.category ?? "")
        _address = State(initialValue: currentProfile?.address ?? "")
    }
    
    var body: some View {
        Form {
            Section(
                header: Text("Legal Information"),
                footer: Text("Core legal identifiers are verified by your Issuing LGU and cannot be modified.")
            ) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text("Business Name")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    TextField("Business Name", text: $businessName)
                        .disabled(true)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 2)
                .listRowBackground(Color(.systemGray6))
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text("Permit Number")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    TextField("Permit Number", text: $permitNumber)
                        .disabled(true)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 2)
                .listRowBackground(Color(.systemGray6))
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text("TIN")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    TextField("TIN", text: $tin)
                        .disabled(true)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 2)
                .listRowBackground(Color(.systemGray6))
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text("Issuing LGU")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    TextField("Issuing LGU", text: $issuingLGU)
                        .disabled(true)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 2)
                .listRowBackground(Color(.systemGray6))
            }
            
            Section(header: Text("Editable Details")) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Branch Name")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Branch Name", text: $branchName)
                }
                .padding(.vertical, 2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Category")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Category", text: $category)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                }
                .padding(.vertical, 2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Address")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Address", text: $address)
                }
                .padding(.vertical, 2)
                
                Button(action: saveChanges) {
                    HStack {
                        Spacer()
                        if isSaving {
                            ProgressView()
                                .padding(.trailing, 8)
                            Text("Saving Changes...")
                                .fontWeight(.semibold)
                        } else {
                            Text("Save Changes")
                                .fontWeight(.semibold)
                        }
                        Spacer()
                    }
                }
                .disabled(
                    isSaving ||
                    isLoadingProfile ||
                    category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            }
        }
        .navigationTitle("Business Profile")
        .navigationBarTitleDisplayMode(.inline)
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
    
    private func applyProfile(_ profile: BusinessProfile) {
        businessName = profile.businessName
        permitNumber = profile.businessPermitNo
        tin = profile.tinNumber
        if let lguName = profile.lguName, !lguName.isEmpty {
            issuingLGU = lguName
        }
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
                    branchName: branchName,
                    category: category,
                    address: address
                )
                isSaving = false
                applyProfile(updated)
                onProfileUpdated?(updated)
                showSuccessAlert = true
            } catch {
                isSaving = false
                errorMessage = error.localizedDescription
                showErrorAlert = true
            }
        }
    }
}
