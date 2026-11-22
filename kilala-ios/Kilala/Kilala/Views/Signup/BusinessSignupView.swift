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

    @FocusState private var focusedField: Field?

    private enum Field {
        case businessName
        case branchName
        case permitNo
        case tinNumber
        case address
        case email
        case password
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
        ZStack {
            Color.kilalaPaper
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    // Editorial Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Register a Business")
                            .font(.kilala(size: 28, weight: .bold, relativeTo: .title))
                            .foregroundColor(.kilalaInk)

                        Text("Create an accredited merchant account. Fields marked with * are required.")
                            .font(.kilala(.callout))
                            .foregroundColor(.kilalaInkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 8)

                    // Section 1: Issuing LGU
                    VStack(alignment: .leading, spacing: 8) {
                        sectionHeader("Issuing LGU")

                        VStack(alignment: .leading, spacing: 12) {
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
                                HStack(spacing: 12) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.kilalaStateInvalid)
                                        .accessibilityHidden(true)

                                    Text("Unable to load LGUs")
                                        .font(.kilala(.callout, weight: .medium))
                                        .foregroundColor(.kilalaInk)

                                    Spacer()

                                    Button("Retry") {
                                        Task { await loadLGUs() }
                                    }
                                    .font(.kilala(.subheadline, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 14)
                                    .frame(minHeight: 36)
                                    .background(Color.kilalaGreen)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
                            } else {
                                VStack(alignment: .leading, spacing: 8) {
                                    fieldLabel("Select LGU *")

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

                    // Section 2: Business Information
                    VStack(alignment: .leading, spacing: 8) {
                        sectionHeader("Business Information")

                        VStack(alignment: .leading, spacing: 16) {
                            // Business Name
                            VStack(alignment: .leading, spacing: 8) {
                                fieldLabel("Business Name *")
                                TextField("Business Name *", text: $businessName)
                                    .font(.kilala(.body))
                                    .foregroundColor(.kilalaInk)
                                    .tint(.kilalaGreen)
                                    .submitLabel(.next)
                                    .focused($focusedField, equals: .businessName)
                                    .onSubmit { focusedField = .branchName }
                                    .kilalaInputChrome(isFocused: focusedField == .businessName)
                            }

                            // Branch Name
                            VStack(alignment: .leading, spacing: 8) {
                                fieldLabel("Branch Name (Optional)")
                                TextField("Branch Name (Optional)", text: $branchName)
                                    .font(.kilala(.body))
                                    .foregroundColor(.kilalaInk)
                                    .tint(.kilalaGreen)
                                    .submitLabel(.next)
                                    .focused($focusedField, equals: .branchName)
                                    .onSubmit { focusedField = .permitNo }
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

                            // Business Permit No.
                            VStack(alignment: .leading, spacing: 8) {
                                fieldLabel("Business Permit No. *")
                                TextField("Business Permit No. *", text: $businessPermitNo)
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
                                TextField("TIN Number *", text: $tinNumber)
                                    .font(.kilalaMono(.body, weight: .medium))
                                    .foregroundColor(.kilalaInk)
                                    .tint(.kilalaGreen)
                                    .keyboardType(.numbersAndPunctuation)
                                    .autocorrectionDisabled()
                                    .submitLabel(.next)
                                    .focused($focusedField, equals: .tinNumber)
                                    .onSubmit { focusedField = .address }
                                    .kilalaInputChrome(isFocused: focusedField == .tinNumber)
                            }

                            // Business Address
                            VStack(alignment: .leading, spacing: 8) {
                                fieldLabel("Business Address *")
                                TextField("Business Address *", text: $address, axis: .vertical)
                                    .lineLimit(1...3)
                                    .font(.kilala(.body))
                                    .foregroundColor(.kilalaInk)
                                    .tint(.kilalaGreen)
                                    .focused($focusedField, equals: .address)
                                    .kilalaInputChrome(isFocused: focusedField == .address)
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

                    // Section 3: Account Credentials
                    VStack(alignment: .leading, spacing: 8) {
                        sectionHeader("Account Credentials")

                        VStack(alignment: .leading, spacing: 16) {
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
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .submitLabel(.next)
                                    .focused($focusedField, equals: .email)
                                    .onSubmit { focusedField = .password }
                                    .kilalaInputChrome(isFocused: focusedField == .email)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                fieldLabel("Password *")
                                SecureField("Password *", text: $password)
                                    .font(.kilala(.body))
                                    .foregroundColor(.kilalaInk)
                                    .tint(.kilalaGreen)
                                    .submitLabel(.done)
                                    .focused($focusedField, equals: .password)
                                    .kilalaInputChrome(isFocused: focusedField == .password)
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

                    // Primary Submit Button
                    Button(action: submitRegistration) {
                        HStack(spacing: 8) {
                            if isSubmitting {
                                ProgressView()
                                    .tint(.white)
                                Text("Registering Business...")
                                    .font(.kilala(.headline, weight: .bold))
                                    .foregroundColor(.white)
                            } else {
                                Text("Register Business")
                                    .font(.kilala(.headline, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.kilalaGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .disabled(!isFormValid || isSubmitting)
                    .opacity((!isFormValid || isSubmitting) ? 0.55 : 1.0)
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 16)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle("Register Business")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.kilalaPaper, for: .navigationBar)
        .task {
            await loadLGUs()
        }
        .alert(alertTitle, isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
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

    // MARK: - Networking

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

        focusedField = nil
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
