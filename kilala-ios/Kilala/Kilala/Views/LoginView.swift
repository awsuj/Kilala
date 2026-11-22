import SwiftUI

struct LoginView: View {
    var onLoginSuccess: (LoginResponse) -> Void

    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String? = nil
    @State private var isLoading = false

    @FocusState private var focusedField: Field?

    private enum Field {
        case email
        case password
    }

    private var isLoginDisabled: Bool {
        isLoading || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.kilalaPaper
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        // Editorial Header (No Boxed Hero Card)
                        VStack(alignment: .leading, spacing: 12) {
                            KilalaBrandLogo(iconSize: 28, wordmarkSize: 24)
                                .accessibilityAddTraits(.isStaticText)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Sign in to Kilala")
                                    .font(.kilala(size: 28, weight: .bold, relativeTo: .title))
                                    .foregroundColor(.kilalaInk)

                                Text("Digital PWD & Senior Citizen verification")
                                    .font(.kilala(.callout))
                                    .foregroundColor(.kilalaInkSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.top, 24)

                        // Single Flat White Form Card
                        VStack(alignment: .leading, spacing: 16) {
                            // Email Input
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Email")
                                    .font(.kilala(.subheadline, weight: .bold))
                                    .foregroundColor(.kilalaInk)

                                TextField(
                                    "Email",
                                    text: $email,
                                    prompt: Text(verbatim: "name@example.com").foregroundStyle(Color.kilalaInk.opacity(0.4))
                                )
                                    .font(.kilala(.body))
                                    .foregroundColor(.kilalaInk)
                                    .tint(.kilalaGreen)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled(true)
                                    .keyboardType(.emailAddress)
                                    .textContentType(.emailAddress)
                                    .submitLabel(.next)
                                    .focused($focusedField, equals: .email)
                                    .onSubmit {
                                        focusedField = .password
                                    }
                                    .padding(.horizontal, 12)
                                    .frame(minHeight: 48)
                                    .background(Color.kilalaPaper.opacity(0.6))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(
                                                focusedField == .email ? Color.kilalaGreen : Color.kilalaBorder,
                                                lineWidth: focusedField == .email ? 1.5 : 1
                                            )
                                    )
                            }

                            // Password Input
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Password")
                                    .font(.kilala(.subheadline, weight: .bold))
                                    .foregroundColor(.kilalaInk)

                                SecureField("Enter your password", text: $password)
                                    .font(.kilala(.body))
                                    .foregroundColor(.kilalaInk)
                                    .tint(.kilalaGreen)
                                    .textContentType(.password)
                                    .submitLabel(.go)
                                    .focused($focusedField, equals: .password)
                                    .onSubmit {
                                        if !isLoginDisabled {
                                            performLogin()
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .frame(minHeight: 48)
                                    .background(Color.kilalaPaper.opacity(0.6))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(
                                                focusedField == .password ? Color.kilalaGreen : Color.kilalaBorder,
                                                lineWidth: focusedField == .password ? 1.5 : 1
                                            )
                                    )
                            }

                            // Inline Error Banner (Icon + Label, never color alone)
                            if let errorMessage = errorMessage {
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.kilalaStateInvalid)
                                        .padding(.top, 1)
                                        .accessibilityHidden(true)

                                    Text(errorMessage)
                                        .font(.kilala(.subheadline, weight: .semibold))
                                        .foregroundColor(.kilalaStateInvalid)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(Color.kilalaStateInvalid.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(Color.kilalaStateInvalid.opacity(0.30), lineWidth: 1)
                                )
                            }

                            // Primary Sign In Button
                            Button(action: performLogin) {
                                HStack(spacing: 8) {
                                    if isLoading {
                                        ProgressView()
                                            .tint(.white)
                                        Text("Signing In...")
                                            .font(.kilala(.headline, weight: .bold))
                                            .foregroundColor(.white)
                                    } else {
                                        Text("Sign In")
                                            .font(.kilala(.headline, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Color.kilalaGreen)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .disabled(isLoginDisabled)
                            .opacity(isLoginDisabled ? 0.55 : 1.0)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.kilalaMintBorder, lineWidth: 1)
                        )

                        // Understated Account Creation Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                Divider()
                                    .overlay(Color.kilalaBorder)

                                Text("New to Kilala?")
                                    .font(.kilala(.footnote, weight: .semibold))
                                    .foregroundColor(.kilalaInkSecondary)
                                    .fixedSize()

                                Divider()
                                    .overlay(Color.kilalaBorder)
                            }

                            NavigationLink {
                                BusinessSignupView(onRegistrationSuccess: onLoginSuccess)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "storefront")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(.kilalaGreen)
                                        .accessibilityHidden(true)

                                    Text("Register a Business")
                                        .font(.kilala(.callout, weight: .bold))
                                        .foregroundColor(.kilalaGreen)

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.kilalaGreen.opacity(0.7))
                                        .accessibilityHidden(true)
                                }
                                .padding(.horizontal, 16)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 50)
                                .background(Color.kilalaMint)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.kilalaMintBorder, lineWidth: 1)
                                )
                            }

                            NavigationLink {
                                CardholderSignupView(onRegistrationSuccess: onLoginSuccess)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "person.text.rectangle")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(.kilalaGreen)
                                        .accessibilityHidden(true)

                                    Text("Claim Cardholder ID")
                                        .font(.kilala(.callout, weight: .bold))
                                        .foregroundColor(.kilalaGreen)

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.kilalaGreen.opacity(0.7))
                                        .accessibilityHidden(true)
                                }
                                .padding(.horizontal, 16)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 50)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.kilalaGreen, lineWidth: 1)
                                )
                            }
                        }
                        .padding(.bottom, 24)
                    }
                    .padding(.horizontal, 16)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .tint(.kilalaGreen)
    }

    private func performLogin() {
        focusedField = nil
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
