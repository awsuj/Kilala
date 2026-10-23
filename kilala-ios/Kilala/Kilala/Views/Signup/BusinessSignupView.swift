//
//  BusinessSignupView.swift
//  Kilala
//
//  Created by Joshua Calibo on 10/23/26.
//

import SwiftUI

struct BusinessSignupView: View {
    var onRegistrationSuccess: (LoginResponse) -> Void
    
    // LGU Selection
    @State private var lgus: [LGU] = []
    @State private var selectedLGUId: UUID? = nil
    @State private var isLoadingLGUs = false
    
    // Business Details
    @State private var businessName = ""
    @State private var branchName = ""
    @State private var selectedCategory = "OTHER"
    @State private var businessPermitNo = ""
    @State private var tinNumber = ""
    @State private var address = ""
    
    // Account Credentials
    @State private var email = ""
    @State private var password = ""
    
    // Submission & Alert State
    @State private var isSubmitting = false
    @State private var alertTitle = "Registration Error"
    @State private var alertMessage = ""
    @State private var showErrorAlert = false
    
    private let categories = [
        "PHARMACY",
        "RESTAURANT",
        "GROCERY",
        "TRANSPORT",
        "MEDICAL",
        "ENTERTAINMENT",
        "OTHER"
    ]
    
    private var isFormValid: Bool {
        selectedLGUId != nil &&
        !businessName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !businessPermitNo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !tinNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !password.isEmpty
    }
    
    var body: some View {
        Form {
            Section(header: Text("Issuing LGU")) {
                if isLoadingLGUs {
                    HStack {
                        ProgressView()
                        Text("Loading LGUs...")
                            .foregroundColor(.secondary)
                    }
                } else if lgus.isEmpty {
                    HStack {
                        Text("Unable to load LGUs")
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Retry") {
                            Task { await loadLGUs() }
                        }
                    }
                } else {
                    Picker("Select LGU", selection: $selectedLGUId) {
                        Text("Select an LGU").tag(UUID?.none)
                        ForEach(lgus) { lgu in
                            Text("\(lgu.municipalityName) (\(lgu.lguCode))")
                                .tag(UUID?.some(lgu.id))
                        }
                    }
                }
            }
            
            Section(header: Text("Business Information")) {
                TextField("Business Name *", text: $businessName)
                
                TextField("Branch Name (Optional)", text: $branchName)
                
                Picker("Category", selection: $selectedCategory) {
                    ForEach(categories, id: \.self) { category in
                        Text(category.capitalized)
                            .tag(category)
                    }
                }
                
                TextField("Business Permit No. *", text: $businessPermitNo)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                
                TextField("TIN Number *", text: $tinNumber)
                    .keyboardType(.numbersAndPunctuation)
                    .autocorrectionDisabled()
                
                TextField("Business Address *", text: $address)
            }
            
            Section(
                header: Text("Account Credentials"),
                footer: Text("Fields marked with * are required.")
            ) {
                TextField("Email Address *", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                
                SecureField("Password *", text: $password)
            }
            
            Section {
                Button(action: submitRegistration) {
                    HStack {
                        Spacer()
                        if isSubmitting {
                            ProgressView()
                                .padding(.trailing, 8)
                            Text("Registering Business...")
                                .fontWeight(.semibold)
                        } else {
                            Text("Register Business")
                                .fontWeight(.semibold)
                        }
                        Spacer()
                    }
                }
                .disabled(!isFormValid || isSubmitting)
            }
        }
        .navigationTitle("Register Business")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadLGUs()
        }
        .alert(alertTitle, isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }
    
    private func loadLGUs() async {
        isLoadingLGUs = true
        do {
            let fetched = try await APIService.shared.fetchLGUs()
            lgus = fetched
            if selectedLGUId == nil, let first = fetched.first {
                selectedLGUId = first.id
            }
        } catch {
            // Keep lgus empty so user can tap Retry
        }
        isLoadingLGUs = false
    }
    
    private func submitRegistration() {
        guard let selectedLGUId = selectedLGUId, isFormValid else { return }
        
        isSubmitting = true
        
        var payload: [String: Any] = [
            "email": email.trimmingCharacters(in: .whitespacesAndNewlines),
            "password": password,
            "lgu_id": selectedLGUId.uuidString,
            "business_name": businessName.trimmingCharacters(in: .whitespacesAndNewlines),
            "category": selectedCategory,
            "business_permit_no": businessPermitNo.trimmingCharacters(in: .whitespacesAndNewlines),
            "tin_number": tinNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            "address": address.trimmingCharacters(in: .whitespacesAndNewlines)
        ]
        
        let trimmedBranch = branchName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedBranch.isEmpty {
            payload["branch_name"] = trimmedBranch
        }
        
        Task {
            do {
                let response = try await APIService.shared.registerBusiness(payload: payload)
                isSubmitting = false
                
                let loginResponse = LoginResponse(
                    message: response.message,
                    token: response.token,
                    user: response.user
                )
                onRegistrationSuccess(loginResponse)
            } catch let apiError as APIError {
                isSubmitting = false
                switch apiError {
                case .conflict(let message):
                    alertTitle = "Duplicate Registration"
                    alertMessage = message
                case .badRequest(let message):
                    alertTitle = "Invalid Input"
                    alertMessage = message
                case .serverError(let message):
                    alertTitle = "Registration Error"
                    alertMessage = message
                }
                showErrorAlert = true
            } catch {
                isSubmitting = false
                alertTitle = "Connection Error"
                alertMessage = "Could not connect to the server. Please check your network connection and try again."
                showErrorAlert = true
            }
        }
    }
}
