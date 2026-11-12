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
                    .accessibilityIdentifier("login.email")
                
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .accessibilityIdentifier("login.password")
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("login.error")
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
                .accessibilityIdentifier("login.submit")
                
                NavigationLink {
                    CardholderSignupView(onSignupSuccess: onLoginSuccess)
                } label: {
                    Text("Create new account")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .accessibilityIdentifier("login.createAccount")
                
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
                .accessibilityIdentifier("login.registerBusiness")
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
            } catch let apiError as APIError {
                // Wrong password, deactivated account, missing fields or a server error:
                // APIService already turned these into user-facing messages.
                errorMessage = apiError.localizedDescription
                isLoading = false
            } catch is URLError {
                errorMessage = "Can't reach the Kilala server. Check your internet connection and try again."
                isLoading = false
            } catch {
                errorMessage = "Something went wrong. Please try again."
                isLoading = false
            }
        }
    }
}
