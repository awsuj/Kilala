//
//  LoginView.swift
//  Kilala
//
//  Created by Joshua Calibo on 10/21/26.
//

import SwiftUI

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String? = nil
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Kilala")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            TextField("Email", text: $email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .keyboardType(.emailAddress)
            
            SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.footnote)
            }
            
            Button(action: performLogin) {
                if isLoading {
                    ProgressView()
                } else {
                    Text("Login")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            .disabled(isLoading || email.isEmpty || password.isEmpty)
        }
        .padding()
    }
    
    private func performLogin() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let response = try await APIService.shared.login(email: email, password: password)
                
                // For now, we will just print it to prove it works.
                // Later, we will save this to the Keychain and navigate to the ID View.
                print("✅ Login Successful!")
                print("User: \(response.user.email)")
                print("Token: \(response.token)")
                
                isLoading = false
            } catch {
                errorMessage = "Failed to login. Check credentials and server."
                isLoading = false
            }
        }
    }
}

#Preview {
    LoginView()
}
