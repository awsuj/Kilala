//
//  SessionManager.swift
//  Kilala
//
//  Persists the active JWT token in the iOS Keychain and non-sensitive
//  user/profile metadata in UserDefaults so both Business and Cardholder
//  sessions survive app restarts.
//

import Combine
import Foundation
import Security

private enum KeychainTokenStore {
    private static let service = Bundle.main.bundleIdentifier ?? "com.kilala.ios"
    private static let account = "kilala.auth.jwt"

    static func save(_ token: String) {
        guard let data = token.data(using: .utf8) else { return }

        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let attributesToUpdate: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributesToUpdate as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }

        if updateStatus != errSecItemNotFound {
            SecItemDelete(baseQuery as CFDictionary)
        }

        var addQuery = baseQuery
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    static func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8),
              !token.isEmpty else {
            return nil
        }
        return token
    }

    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

@MainActor
final class SessionManager: ObservableObject {
    static let shared = SessionManager()

    @Published private(set) var session: LoginResponse?

    private enum StorageKey {
        static let user = "kilala.session.user"
        static let businessProfile = "kilala.session.businessProfile"
        static let cardholderProfile = "kilala.session.cardholderProfile"
    }

    private let defaults: UserDefaults
    private var needsLaunchRefresh = false

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        restoreSession()
    }

    // MARK: - Restore on Launch

    private func restoreSession() {
        let savedToken = KeychainTokenStore.load()
        let savedUser: User? = loadCodable(User.self, forKey: StorageKey.user)

        guard let token = savedToken, !token.isEmpty, let user = savedUser else {
            // Clean up any partial/orphaned state without overwriting an unrelated fresh install
            if savedToken != nil || savedUser != nil {
                clearPersistedStorage()
            }
            self.session = nil
            self.needsLaunchRefresh = false
            return
        }

        let cachedBusinessProfile = loadCodable(BusinessProfile.self, forKey: StorageKey.businessProfile)
        let cachedCardholderProfile = loadCodable(CardholderProfile.self, forKey: StorageKey.cardholderProfile)

        APIService.shared.authToken = token
        APIService.shared.currentUserEmail = user.email
        APIService.shared.currentBusinessProfile = user.role == .business ? cachedBusinessProfile : nil
        APIService.shared.currentCardholderProfile = user.role == .cardholder ? cachedCardholderProfile : nil

        self.session = LoginResponse(
            message: "Session restored",
            token: token,
            user: user
        )
        self.needsLaunchRefresh = true
    }

    // MARK: - Persist Session

    func saveSession(
        _ loginResponse: LoginResponse,
        businessProfile: BusinessProfile? = nil,
        cardholderProfile: CardholderProfile? = nil
    ) {
        KeychainTokenStore.save(loginResponse.token)
        saveCodable(loginResponse.user, forKey: StorageKey.user)

        switch loginResponse.user.role {
        case .business:
            let resolvedProfile = businessProfile ?? APIService.shared.currentBusinessProfile
            if let resolvedProfile {
                saveCodable(resolvedProfile, forKey: StorageKey.businessProfile)
            } else {
                defaults.removeObject(forKey: StorageKey.businessProfile)
            }
            defaults.removeObject(forKey: StorageKey.cardholderProfile)
            APIService.shared.currentBusinessProfile = resolvedProfile
            APIService.shared.currentCardholderProfile = nil

        case .cardholder:
            let resolvedProfile = cardholderProfile ?? APIService.shared.currentCardholderProfile
            if let resolvedProfile {
                saveCodable(resolvedProfile, forKey: StorageKey.cardholderProfile)
            } else {
                defaults.removeObject(forKey: StorageKey.cardholderProfile)
            }
            defaults.removeObject(forKey: StorageKey.businessProfile)
            APIService.shared.currentCardholderProfile = resolvedProfile
            APIService.shared.currentBusinessProfile = nil

        case .lguAdmin, .superAdmin:
            defaults.removeObject(forKey: StorageKey.businessProfile)
            defaults.removeObject(forKey: StorageKey.cardholderProfile)
            APIService.shared.currentBusinessProfile = nil
            APIService.shared.currentCardholderProfile = nil
        }

        APIService.shared.authToken = loginResponse.token
        APIService.shared.currentUserEmail = loginResponse.user.email

        self.needsLaunchRefresh = false
        self.session = loginResponse
    }

    // MARK: - Profile & Email Cache Updates

    func updateCachedBusinessProfile(_ profile: BusinessProfile) {
        guard session != nil else { return }
        saveCodable(profile, forKey: StorageKey.businessProfile)
    }

    func updateCachedCardholderProfile(_ profile: CardholderProfile) {
        guard session != nil else { return }
        saveCodable(profile, forKey: StorageKey.cardholderProfile)
        if let email = profile.email?.trimmingCharacters(in: .whitespacesAndNewlines),
           !email.isEmpty {
            updateUserEmail(email)
        }
    }

    func updateUserEmail(_ email: String) {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let currentSession = session else { return }

        APIService.shared.currentUserEmail = trimmed
        guard currentSession.user.email != trimmed else { return }

        let updatedUser = User(
            id: currentSession.user.id,
            email: trimmed,
            role: currentSession.user.role
        )
        saveCodable(updatedUser, forKey: StorageKey.user)
        self.session = LoginResponse(
            message: currentSession.message,
            token: currentSession.token,
            user: updatedUser
        )
    }

    // MARK: - Background Refresh on Launch

    func refreshRestoredSessionIfNeeded() async {
        guard needsLaunchRefresh, let currentSession = session else { return }
        needsLaunchRefresh = false

        APIService.shared.authToken = currentSession.token

        do {
            switch currentSession.user.role {
            case .business:
                let profile = try await APIService.shared.fetchBusinessProfile()
                updateCachedBusinessProfile(profile)
            case .cardholder:
                let profile = try await APIService.shared.getCardholderProfile(token: currentSession.token)
                updateCachedCardholderProfile(profile)
            case .lguAdmin, .superAdmin:
                break
            }
        } catch {
            // Do not log out on offline/network/temporary errors.
            // If the server returned 401 Unauthorized (or invalid/expired token),
            // APIService triggers handleUnauthorized() to clear the session cleanly.
        }
    }

    // MARK: - Logout & Unauthorized Handling

    func handleUnauthorized() {
        guard session != nil else { return }
        clearSession()
    }

    func logout() {
        clearSession()
    }

    private func clearSession() {
        clearPersistedStorage()
        APIService.shared.authToken = nil
        APIService.shared.currentUserEmail = nil
        APIService.shared.currentBusinessProfile = nil
        APIService.shared.currentCardholderProfile = nil
        self.needsLaunchRefresh = false
        self.session = nil
    }

    private func clearPersistedStorage() {
        KeychainTokenStore.delete()
        defaults.removeObject(forKey: StorageKey.user)
        defaults.removeObject(forKey: StorageKey.businessProfile)
        defaults.removeObject(forKey: StorageKey.cardholderProfile)
    }

    // MARK: - UserDefaults Codable Helpers

    private func saveCodable<T: Encodable>(_ value: T, forKey key: String) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        }
    }

    private func loadCodable<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
