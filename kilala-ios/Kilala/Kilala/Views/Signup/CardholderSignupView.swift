//
//  CardholderSignupView.swift
//  Kilala
//
//  Created by Eunice Santos on 10/23/26.
//

import SwiftUI

struct CardholderSignupView: View {
    @State private var privilege_type: PrivilegeType = .pwd
    @State private var card_id_number: String = ""
    @State private var first_name: String = ""
    @State private var middle_name: String = ""
    @State private var last_name: String = ""
    @State private var date_of_birth: Date = Date()
    
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
                            isSelected: privilege_type == .pwd
                        ) {
                            privilege_type = .pwd
                        }
                        
                        OptionCardView(
                            title: "Senior Citizen",
                            icon: "figure.walk",
                            isSelected: privilege_type == .seniorCitizen
                        ) {
                            privilege_type = .seniorCitizen
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
                    CustomTextField(text: $first_name)
                }
                // middle name
                VStack(alignment: .leading, spacing: 8) {
                    Text("Middle Name")
                        .font(.footnote)
                        .fontWeight(.bold)
                    CustomTextField(text: $middle_name)
                }
                // last name
                VStack(alignment: .leading, spacing: 8) {
                    Text("Last Name")
                        .font(.footnote)
                        .fontWeight(.bold)
                    CustomTextField(text: $last_name)
                }
                
                // card number
                VStack(alignment: .leading, spacing: 8) {
                    Text("Physical Card Number")
                        .font(.footnote)
                        .fontWeight(.bold)
                    CustomTextField(text: $card_id_number)
                }
                
                // birth date
                VStack(alignment: .leading, spacing: 8) {
                    Text("Birth Date")
                        .font(.footnote)
                        .fontWeight(.bold)
                    HStack {
                        DatePicker("Select date", selection: $date_of_birth, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .environment(\.locale, Locale(identifier: "en_PH"))
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 8)
                    .background(Color(white: 0.92))
                    .overlay(
                        Rectangle()
                            .stroke(Color.gray.opacity(0.6), lineWidth: 1)
                    )
                }
                
                // submit
                Button(action: {
                    print("Verifying \(card_id_number) for \(first_name) \(last_name) ...")
                }) {
                    Text("Verify Record")
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(white: 0.25))
                }
                .padding(.top, 10)
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 20)
        }
        .navigationBarHidden(true)
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
                .overlay(
                    Rectangle()
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
            .overlay(
                Rectangle()
                    .stroke(Color.gray.opacity(0.6), lineWidth: 1)
            )
    }
}

struct UploadBoxView: View {
    var placeholder: String
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(white: 0.92))
                .overlay(
                    Rectangle()
                        .stroke(Color.gray.opacity(0.6), lineWidth: 1)
                )
            
            Text(placeholder)
                .foregroundColor(.gray)
                .font(.footnote)
                .multilineTextAlignment(.center)
        }
        .frame(height: 120)
    }
}

struct CardholderSignupView_Previews: PreviewProvider {
    static var previews: some View {
        CardholderSignupView()
    }
}
