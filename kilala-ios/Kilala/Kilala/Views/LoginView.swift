import SwiftUI

struct LoginView: View {
    var onLoginSuccess: (LoginResponse) -> Void
    
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String? = nil
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()
                
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
                
                Spacer()
                
                Divider()
                
                NavigationLink {
                    BusinessSignupView(onRegistrationSuccess: onLoginSuccess)
                } label: {
                    Text("Register your Business")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.vertical, 8)
                }
            }
            .padding()
        }
    }
    
    private func performLogin() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let response = try await APIService.shared.login(email: email, password: password)
                isLoading = false
                onLoginSuccess(response)
            } catch {
                errorMessage = "Invalid credentials or server offline."
                isLoading = false
            }
        }
    }
}
