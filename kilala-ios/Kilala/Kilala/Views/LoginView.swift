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
        isLoading || email.isEmpty || password.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.kilalaPaper
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        // Brand Header
                        VStack(spacing: 12) {
                            KilalaBrandLogo(iconSize: 38, wordmarkSize: 34)
                                .accessibilityAddTraits(.isStaticText)

                            Text("Sign in to access your Digital ID or Merchant Portal")
                                .font(.kilala(.subheadline, weight: .medium))
                                .foregroundColor(.kilalaInkSecondary)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, 12)
                        }
                        .padding(.top, 36)

                        // Mint Form Card
                        VStack(alignment: .leading, spacing: 18) {
                            // Email Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("EMAIL")
                                    .font(.kilala(.caption, weight: .bold))
                                    .tracking(0.8)
                                    .foregroundColor(.kilalaInkSecondary)

                                HStack(spacing: 10) {
                                    Image(systemName: "envelope")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.kilalaInkMuted)
                                        .accessibilityHidden(true)

                                    TextField("Email", text: $email)
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
                                }
                                .padding(.horizontal, 14)
                                .frame(minHeight: 50)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(
                                            focusedField == .email ? Color.kilalaGreen : Color.kilalaMintBorder,
                                            lineWidth: focusedField == .email ? 1.5 : 1
                                        )
                                )
                            }

                            // Password Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("PASSWORD")
                                    .font(.kilala(.caption, weight: .bold))
                                    .tracking(0.8)
                                    .foregroundColor(.kilalaInkSecondary)

                                HStack(spacing: 10) {
                                    Image(systemName: "lock")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.kilalaInkMuted)
                                        .accessibilityHidden(true)

                                    SecureField("Password", text: $password)
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
                                }
                                .padding(.horizontal, 14)
                                .frame(minHeight: 50)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(
                                            focusedField == .password ? Color.kilalaGreen : Color.kilalaMintBorder,
                                            lineWidth: focusedField == .password ? 1.5 : 1
                                        )
                                )
                            }

                            // Error Banner (Icon + Text, never color alone)
                            if let errorMessage = errorMessage {
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.kilalaStateInvalid)
                                        .padding(.top, 1)
                                        .accessibilityHidden(true)

                                    Text(errorMessage)
                                        .font(.kilala(.footnote, weight: .semibold))
                                        .foregroundColor(.kilalaStateInvalid)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(Color.kilalaStateInvalid.opacity(0.10))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.kilalaStateInvalid.opacity(0.30), lineWidth: 1)
                                )
                            }

                            // Primary Sign-In Button
                            Button(action: performLogin) {
                                HStack(spacing: 10) {
                                    if isLoading {
                                        ProgressView()
                                            .tint(.kilalaSunrise)
                                    } else {
                                        Text("Login")
                                            .font(.kilala(.headline, weight: .bold))
                                            .foregroundColor(.white)

                                        Image(systemName: "arrow.right")
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundColor(.kilalaSunrise)
                                            .accessibilityHidden(true)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 54)
                                .background(Color.kilalaGreen)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .shadow(color: Color.kilalaGreen.opacity(isLoginDisabled ? 0.0 : 0.22), radius: 10, x: 0, y: 4)
                            }
                            .disabled(isLoginDisabled)
                            .opacity(isLoginDisabled ? 0.55 : 1.0)
                            .padding(.top, 4)
                        }
                        .padding(22)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.kilalaMint)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(Color.kilalaMintBorder, lineWidth: 1)
                        )

                        // Registration & Account Claim Links
                        VStack(spacing: 14) {
                            HStack(spacing: 12) {
                                Rectangle()
                                    .fill(Color.kilalaBorder)
                                    .frame(height: 1)

                                Text("NEW TO KILALA?")
                                    .font(.kilala(.caption, weight: .bold))
                                    .tracking(0.8)
                                    .foregroundColor(.kilalaInkMuted)
                                    .fixedSize()

                                Rectangle()
                                    .fill(Color.kilalaBorder)
                                    .frame(height: 1)
                            }

                            VStack(spacing: 12) {
                                NavigationLink {
                                    CardholderSignupView(onRegistrationSuccess: onLoginSuccess)
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "person.text.rectangle")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.kilalaGreen)
                                            .accessibilityHidden(true)

                                        Text("Create new account")
                                            .font(.kilala(.subheadline, weight: .bold))
                                            .foregroundColor(.kilalaInk)

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(.kilalaInkMuted)
                                            .accessibilityHidden(true)
                                    }
                                    .padding(.horizontal, 18)
                                    .frame(maxWidth: .infinity)
                                    .frame(minHeight: 50)
                                    .background(Color.kilalaMint)
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.kilalaMintBorder, lineWidth: 1)
                                    )
                                }

                                NavigationLink {
                                    BusinessSignupView(onRegistrationSuccess: onLoginSuccess)
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "storefront")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.kilalaGreen)
                                            .accessibilityHidden(true)

                                        Text("Register your Business")
                                            .font(.kilala(.subheadline, weight: .bold))
                                            .foregroundColor(.kilalaGreen)

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(.kilalaGreen.opacity(0.65))
                                            .accessibilityHidden(true)
                                    }
                                    .padding(.horizontal, 18)
                                    .frame(maxWidth: .infinity)
                                    .frame(minHeight: 50)
                                    .background(Color.white)
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.kilalaMintBorder, lineWidth: 1)
                                    )
                                }
                            }
                        }
                        .padding(.bottom, 24)
                    }
                    .padding(.horizontal, 20)
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
