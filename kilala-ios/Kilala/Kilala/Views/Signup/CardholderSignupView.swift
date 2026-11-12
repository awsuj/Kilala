//
//  CardholderSignupView.swift
//  Kilala
//
//  Created by Eunice Santos on 10/23/26.
//

import SwiftUI

struct CardholderSignupView: View {
    /// Called with the new session after the account is created, so the app can show the Digital ID.
    var onSignupSuccess: (LoginResponse) -> Void

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

    // Step 2: create the login for the verified record (POST /api/auth/claim-cardholder)
    @State private var verifiedCardId: String? = nil
    @State private var verifiedDOB: String? = nil
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var isCreatingAccount: Bool = false
    @State private var accountErrorMessage: String? = nil

    enum PrivilegeType: String {
        case pwd = "PWD"
        case seniorCitizen = "SENIOR_CITIZEN"
    }

    /// Changes whenever a field used to match the LGU record changes.
    private var recordKey: String {
        [privilegeType.rawValue, firstName, middleName, lastName, cardIdNumber,
         String(dateOfBirth.timeIntervalSinceReferenceDate)].joined(separator: "|")
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                // header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Register Account")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .padding(.bottom, 4)

                    Divider()
                        .background(Color.gray)
                        .padding(.bottom, 8)

                    Text("Match your LGU record")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.gray)
                }
                .padding(.top, 16)

                // id type selection
                VStack(alignment: .center, spacing: 16) {
                    Text("Select your ID type")
                        .font(.headline)
                        .fontWeight(.bold)

                    HStack(spacing: 20) {
                        OptionCardView(
                            title: "PWD",
                            icon: "figure.roll",
                            isSelected: privilegeType == .pwd
                        ) {
                            privilegeType = .pwd
                        }
                        .accessibilityIdentifier("signup.type.pwd")

                        OptionCardView(
                            title: "Senior Citizen",
                            icon: "figure.walk",
                            isSelected: privilegeType == .seniorCitizen
                        ) {
                            privilegeType = .seniorCitizen
                        }
                        .accessibilityIdentifier("signup.type.senior")
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
                }
                .frame(maxWidth: .infinity)

                // names
                // first name
                VStack(alignment: .leading, spacing: 8) {
                    Text("First Name")
                        .font(.footnote)
                        .fontWeight(.bold)
                    CustomTextField(text: $firstName, identifier: "signup.firstName")
                }
                // middle name
                VStack(alignment: .leading, spacing: 8) {
                    Text("Middle Name")
                        .font(.footnote)
                        .fontWeight(.bold)
                    CustomTextField(text: $middleName, identifier: "signup.middleName")
                    // The LGU record is matched on the middle name too, so a blank field only
                    // matches records that have no middle name.
                    Text("Enter it exactly as shown on your ID. Leave blank only if your ID has no middle name.")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                // last name
                VStack(alignment: .leading, spacing: 8) {
                    Text("Last Name")
                        .font(.footnote)
                        .fontWeight(.bold)
                    CustomTextField(text: $lastName, identifier: "signup.lastName")
                }

                // card number
                VStack(alignment: .leading, spacing: 8) {
                    Text("Physical Card Number")
                        .font(.footnote)
                        .fontWeight(.bold)
                    CustomTextField(text: $cardIdNumber, identifier: "signup.cardNumber", autocapitalize: false)
                }

                // date of birth
                VStack(alignment: .leading, spacing: 8) {
                    Text("Date of Birth")
                        .font(.footnote)
                        .fontWeight(.bold)
                    HStack {
                        // Birth dates can't be in the future.
                        DatePicker("Select date", selection: $dateOfBirth, in: ...Date(), displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .environment(\.locale, Locale(identifier: "en_PH"))
                            .accessibilityIdentifier("signup.dateOfBirth")
                        Spacer()
                        Image(systemName: "calendar")
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 8)
                    .background(Color(white: 0.92))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.6), lineWidth: 1)
                    )
                }

                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .accessibilityIdentifier("signup.error")
                }

                if isVerified, let profile = verifiedProfile {
                    Text("Verified: \(profile.firstName) \(profile.lastName)!")
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .accessibilityIdentifier("signup.verified")

                    createLoginSection
                } else {
                    // submit
                    Button(action: handleVerifyRecord) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color(white: 0.25))
                                .cornerRadius(8)
                        } else {
                            Text("Verify Record")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color(white: 0.25))
                                .cornerRadius(8)
                        }
                    }
                    .disabled(isLoading)
                    .accessibilityIdentifier("signup.verify")
                    .padding(.top, 10)
                    .padding(.bottom, 40)
                }
            }
            .padding(.horizontal, 20)
        }
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: recordKey) {
            // Editing the matched details invalidates the verification, so the account
            // is always created for the record that was actually verified.
            if isVerified {
                resetVerification()
            }
        }
    }

    // MARK: Step 2 – create login

    private var createLoginSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Create your login")
                .font(.headline)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 8) {
                Text("Email")
                    .font(.footnote)
                    .fontWeight(.bold)
                CustomTextField(text: $email, identifier: "signup.email",
                                keyboardType: .emailAddress, autocapitalize: false)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(.footnote)
                    .fontWeight(.bold)
                CustomTextField(text: $password, identifier: "signup.password", isSecure: true)
                Text("At least \(InputValidation.minimumPasswordLength) characters.")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Confirm Password")
                    .font(.footnote)
                    .fontWeight(.bold)
                CustomTextField(text: $confirmPassword, identifier: "signup.confirmPassword", isSecure: true)
            }

            if let accountErrorMessage = accountErrorMessage {
                Text(accountErrorMessage)
                    .font(.footnote)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .accessibilityIdentifier("signup.accountError")
            }

            Button(action: handleCreateAccount) {
                Group {
                    if isCreatingAccount {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Create Account")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color(white: 0.25))
                .cornerRadius(8)
            }
            .disabled(isCreatingAccount)
            .accessibilityIdentifier("signup.createAccount")
            .padding(.top, 10)
            .padding(.bottom, 40)
        }
    }

    // MARK: Actions

    private func handleVerifyRecord() {
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

        // The picker starts on today's date, which can't be a real birth date.
        guard !Calendar.current.isDateInToday(dateOfBirth) else {
            errorMessage = "Please select your date of birth."
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
                    self.verifiedCardId = trimmedCardId
                    self.verifiedDOB = formattedDOB
                    self.isLoading = false
                    self.isVerified = true
                }
            } catch {
                await MainActor.run {
                    var message = error.localizedDescription
                    if let apiError = error as? APIError, case .badRequest = apiError, trimmedMiddle.isEmpty {
                        message += " If your ID shows a middle name, enter it as well."
                    }
                    self.errorMessage = message
                    self.isLoading = false
                }
            }
        }
    }

    private func handleCreateAccount() {
        accountErrorMessage = nil

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard InputValidation.isValidEmail(trimmedEmail) else {
            accountErrorMessage = InputValidation.invalidEmailMessage
            return
        }
        if let problem = InputValidation.passwordProblem(password) {
            accountErrorMessage = problem
            return
        }
        guard password == confirmPassword else {
            accountErrorMessage = "Passwords do not match."
            return
        }
        guard let cardId = verifiedCardId, let dob = verifiedDOB else {
            resetVerification()
            return
        }

        isCreatingAccount = true

        Task {
            do {
                let response = try await APIService.shared.claimCardholder(
                    lguIdNumber: cardId,
                    dateOfBirth: dob,
                    email: trimmedEmail,
                    password: password
                )
                isCreatingAccount = false
                onSignupSuccess(response)
            } catch let apiError as APIError {
                isCreatingAccount = false
                if case .conflict(let message) = apiError {
                    // Also covers a retry after a request whose response was lost.
                    let sentence = message.hasSuffix(".") ? message : message + "."
                    accountErrorMessage = "\(sentence) If you already created your account, go back and log in."
                } else {
                    accountErrorMessage = apiError.localizedDescription
                }
            } catch is URLError {
                isCreatingAccount = false
                accountErrorMessage = "Can't reach the Kilala server. Check your internet connection and try again."
            } catch {
                isCreatingAccount = false
                accountErrorMessage = "Something went wrong. Please try again."
            }
        }
    }

    private func resetVerification() {
        isVerified = false
        verifiedProfile = nil
        verifiedCardId = nil
        verifiedDOB = nil
        accountErrorMessage = nil
    }
}

struct OptionCardView: View {
    var title: String
    var icon: String
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomTrailing) {
                // main content
                VStack(spacing: 12) {
                    Image(systemName: icon)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 32)
                        .foregroundColor(isSelected ? .blue : .gray)

                    Text(title)
                        .font(.footnote)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(Color.white)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.gray.opacity(0.4) : Color.clear, lineWidth: 1)
                )
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CustomTextField: View {
    @Binding var text: String
    /// Accessibility identifier used by the UI tests.
    var identifier: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var autocapitalize: Bool = true

    var body: some View {
        Group {
            if isSecure {
                SecureField("", text: $text)
            } else {
                TextField("", text: $text)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(autocapitalize ? .words : .never)
                    .autocorrectionDisabled(!autocapitalize)
            }
        }
        .accessibilityIdentifier(identifier)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(Color(white: 0.92))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.6), lineWidth: 1)
        )
    }
}

struct CardholderSignupView_Previews: PreviewProvider {
    static var previews: some View {
        CardholderSignupView(onSignupSuccess: { _ in })
    }
}
