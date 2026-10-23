//
//  CardholderSignupView.swift
//  Kilala
//
//  Created by Eunice Santos on 10/23/26.
//

import SwiftUI

struct CardholderSignupView: View {
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
    
    enum PrivilegeType: String {
        case pwd = "PWD"
        case seniorCitizen = "SENIOR_CITIZEN"
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
                        
                        OptionCardView(
                            title: "Senior Citizen",
                            icon: "figure.walk",
                            isSelected: privilegeType == .seniorCitizen
                        ) {
                            privilegeType = .seniorCitizen
                        }
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
                    CustomTextField(text: $firstName)
                }
                // middle name
                VStack(alignment: .leading, spacing: 8) {
                    Text("Middle Name")
                        .font(.footnote)
                        .fontWeight(.bold)
                    CustomTextField(text: $middleName)
                }
                // last name
                VStack(alignment: .leading, spacing: 8) {
                    Text("Last Name")
                        .font(.footnote)
                        .fontWeight(.bold)
                    CustomTextField(text: $lastName)
                }
                
                // card number
                VStack(alignment: .leading, spacing: 8) {
                    Text("Physical Card Number")
                        .font(.footnote)
                        .fontWeight(.bold)
                    CustomTextField(text: $cardIdNumber)
                }
                
                // date of birth
                VStack(alignment: .leading, spacing: 8) {
                    Text("Date of Birth")
                        .font(.footnote)
                        .fontWeight(.bold)
                    HStack {
                        DatePicker("Select date", selection: $dateOfBirth, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .environment(\.locale, Locale(identifier: "en_PH"))
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
                }
                
                if isVerified, let profile = verifiedProfile {
                    Text("Verified: \(profile.firstName) \(profile.lastName)!")
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                
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
                .padding(.top, 10)
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 20)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
    
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
    
    var body: some View {
        TextField("", text: $text)
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
        CardholderSignupView()
    }
}
