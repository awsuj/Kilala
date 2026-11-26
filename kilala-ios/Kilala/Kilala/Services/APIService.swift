//
//  APIService.swift
//  
//
//  Created by Joshua Calibo on 10/21/26.
//

import Foundation

struct LoginResponse: Codable {
    let message: String
    let token: String
    let user: User
}

struct CardholderTransactionHistoryItem: Codable, Identifiable {
    let id: UUID
    let businessId: UUID?
    let cardholderId: UUID?
    let businessName: String
    let branchName: String?
    let category: String?
    let businessCategory: String?
    let originalAmount: Double
    let discountedAmount: Double
    let createdAt: String

    var discountAmount: Double {
        max(0, originalAmount - discountedAmount)
    }

    var formattedCategory: String {
        let raw = (category ?? businessCategory ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else {
            return "Other"
        }
        return raw
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}

enum APIError: LocalizedError {
    case conflict(String)
    case badRequest(String)
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .conflict(let message),
             .badRequest(let message),
             .serverError(let message):
            return message
        }
    }
}

private struct BackendErrorBody: Codable {
    let error: String
}

class APIService {
    static let shared = APIService()
    
    // Debug builds (running from Xcode, and all automated tests) use the local backend, so
    // development and QA never touch the deployed server's data. Release builds (archives
    // for TestFlight / App Store) use the deployed backend.
    // IMPORTANT: If running a Debug build on a physical iPhone, change "localhost" to your
    // Mac's IPv4 address (e.g., "192.168.1.15").
    #if DEBUG
    private let baseURL = "http://localhost:5001/api"
    #else
    private let baseURL = "https://kilala-vyn1.onrender.com/api"
    #endif
    var authToken: String?
    var currentUserEmail: String?
    var currentBusinessProfile: BusinessProfile?
    var currentCardholderProfile: CardholderProfile?
    
    private init() {} // Prevent multiple instances
    
    func login(email: String, password: String) async throws -> LoginResponse {
        guard let url = URL(string: "\(baseURL)/auth/login") else {
            throw URLError(.badURL)
        }
        
        // Prepare the POST request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Encode the email and password payload
        let body = ["email": email, "password": password]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        // Execute the network call
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Check for HTTP errors (e.g., 401 Unauthorized)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            // In a production app, you would decode the error message here
            throw URLError(.badServerResponse)
        }
        
        // Decode the successful JSON response
        let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
        self.authToken = loginResponse.token
        self.currentUserEmail = loginResponse.user.email
        if loginResponse.user.role == .business {
            self.currentBusinessProfile = try? await self.fetchBusinessProfile()
        } else {
            self.currentBusinessProfile = nil
        }
        return loginResponse
    }
    
    func getCardholderProfile(token: String) async throws -> CardholderProfile {
        let activeToken = token.isEmpty ? (self.authToken ?? "") : token
        self.authToken = activeToken
        guard let url = URL(string: "\(baseURL)/cardholder/me") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(activeToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let profile = try decoder.decode(CardholderProfile.self, from: data)
        self.currentCardholderProfile = profile
        if let profileEmail = profile.email, !profileEmail.isEmpty {
            self.currentUserEmail = profileEmail
        }
        return profile
    }
    
    func verifyScan(qrToken: String, token: String) async throws -> VerificationResponse {
        let activeToken = token.isEmpty ? (self.authToken ?? "") : token
        self.authToken = activeToken
        guard let url = URL(string: "\(baseURL)/verify/scan") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(activeToken)", forHTTPHeaderField: "Authorization")
        
        let body = ["qr_token": qrToken.trimmingCharacters(in: .whitespacesAndNewlines)]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        // The backend returns 200 for recognized cards (active, expired, or revoked)
        // and 404 with a VerificationResponse body for unrecognized/counterfeit QR codes.
        if (200...299).contains(httpResponse.statusCode) || httpResponse.statusCode == 404 {
            if let verificationResponse = try? JSONDecoder().decode(VerificationResponse.self, from: data) {
                return verificationResponse
            }
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode(VerificationResponse.self, from: data)
    }
    
    func fetchLGUs() async throws -> [LGU] {
        guard let url = URL(string: "\(baseURL)/lgus") else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode([LGU].self, from: data)
    }
    
    func registerBusiness(payload: [String: Any]) async throws -> BusinessRegistrationResponse {
        guard let url = URL(string: "\(baseURL)/auth/register-business") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode == 409 {
            let backendError = try? JSONDecoder().decode(BackendErrorBody.self, from: data)
            throw APIError.conflict(
                backendError?.error ?? "An account with this email or business permit number already exists."
            )
        }
        
        if httpResponse.statusCode == 400 {
            let backendError = try? JSONDecoder().decode(BackendErrorBody.self, from: data)
            throw APIError.badRequest(
                backendError?.error ?? "Please fill in all required business registration fields."
            )
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let backendError = try? JSONDecoder().decode(BackendErrorBody.self, from: data)
            throw APIError.serverError(
                backendError?.error ?? "Unable to complete business registration. Please try again."
            )
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let registrationResponse = try decoder.decode(BusinessRegistrationResponse.self, from: data)
        self.authToken = registrationResponse.token
        self.currentUserEmail = registrationResponse.user.email
        self.currentBusinessProfile = registrationResponse.businessProfile
        return registrationResponse
    }

    func verifyBusiness(
        businessName: String,
        lgu: String,
        lguId: UUID? = nil,
        tin: String,
        permitNumber: String
    ) async throws -> BusinessVerificationResponse {
        guard let url = URL(string: "\(baseURL)/auth/business/verify") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: String] = [
            "businessName": businessName,
            "lgu": lgu,
            "tin": tin,
            "permitNumber": permitNumber
        ]
        if let lguId {
            body["lgu_id"] = lguId.uuidString
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode == 400 || httpResponse.statusCode == 404 {
            let backendError = try? JSONDecoder().decode(BackendErrorBody.self, from: data)
            throw APIError.badRequest(
                backendError?.error ?? "No matching accredited business record found. Please check your details."
            )
        }
        
        if httpResponse.statusCode == 403 || httpResponse.statusCode == 409 {
            let backendError = try? JSONDecoder().decode(BackendErrorBody.self, from: data)
            throw APIError.conflict(
                backendError?.error ?? "This business record cannot be claimed."
            )
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let backendError = try? JSONDecoder().decode(BackendErrorBody.self, from: data)
            throw APIError.serverError(
                backendError?.error ?? "Unable to verify business accreditation. Please try again."
            )
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(BusinessVerificationResponse.self, from: data)
    }

    func claimBusiness(
        businessId: UUID,
        email: String,
        password: String,
        branchName: String?,
        category: String,
        businessPermitNo: String,
        address: String
    ) async throws -> BusinessRegistrationResponse {
        guard let url = URL(string: "\(baseURL)/auth/claim-business") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = [
            "business_id": businessId.uuidString,
            "email": email,
            "password": password,
            "category": category,
            "business_permit_no": businessPermitNo,
            "address": address
        ]
        if let branchName {
            body["branch_name"] = branchName
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode == 400 || httpResponse.statusCode == 404 {
            let backendError = try? JSONDecoder().decode(BackendErrorBody.self, from: data)
            throw APIError.badRequest(
                backendError?.error ?? "Unable to claim business account. Please check your details."
            )
        }
        
        if httpResponse.statusCode == 403 || httpResponse.statusCode == 409 {
            let backendError = try? JSONDecoder().decode(BackendErrorBody.self, from: data)
            throw APIError.conflict(
                backendError?.error ?? "This business account cannot be claimed."
            )
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let backendError = try? JSONDecoder().decode(BackendErrorBody.self, from: data)
            throw APIError.serverError(
                backendError?.error ?? "Unable to complete business account creation. Please try again."
            )
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let registrationResponse = try decoder.decode(BusinessRegistrationResponse.self, from: data)
        self.authToken = registrationResponse.token
        self.currentUserEmail = registrationResponse.user.email
        self.currentBusinessProfile = registrationResponse.businessProfile
        return registrationResponse
    }

    func verifyRecord(
        privilegeType: String,
        cardIdNumber: String,
        firstName: String,
        middleName: String,
        lastName: String,
        dateOfBirth: String
    ) async throws -> SignupVerificationResponse {
        guard let url = URL(string: "\(baseURL)/auth/verify-record") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = [
            "privilege_type": privilegeType,
            "card_id_number": cardIdNumber,
            "first_name": firstName,
            "middle_name": middleName,
            "last_name": lastName,
            "date_of_birth": dateOfBirth
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode == 400 || httpResponse.statusCode == 404 {
            let backendError = try? JSONDecoder().decode(BackendErrorBody.self, from: data)
            throw APIError.badRequest(backendError?.error ?? "Unable to verify record. Please check your details.")
        }
        
        if httpResponse.statusCode == 403 || httpResponse.statusCode == 409 {
            let backendError = try? JSONDecoder().decode(BackendErrorBody.self, from: data)
            throw APIError.conflict(backendError?.error ?? "This account cannot be claimed.")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(SignupVerificationResponse.self, from: data)
    }

    func requestRegistrationOTP(email: String) async throws {
        guard let url = URL(string: "\(baseURL)/auth/request-otp") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = ["email": email]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode == 400 {
            let backendError = try? JSONDecoder().decode(BackendErrorBody.self, from: data)
            throw APIError.badRequest(backendError?.error ?? "Please enter a valid email address.")
        }
        
        if httpResponse.statusCode == 409 {
            let backendError = try? JSONDecoder().decode(BackendErrorBody.self, from: data)
            throw APIError.conflict(backendError?.error ?? "This email is already in use.")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let backendError = try? JSONDecoder().decode(BackendErrorBody.self, from: data)
            throw APIError.serverError(backendError?.error ?? "Failed to send verification code. Please try again.")
        }
    }

    func verifyOTP(email: String, otp: String) async throws {
        guard let url = URL(string: "\(baseURL)/auth/verify-otp") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = [
            "email": email,
            "otp": otp
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode == 400 {
            let backendError = try? JSONDecoder().decode(BackendErrorBody.self, from: data)
            throw APIError.badRequest(backendError?.error ?? "Invalid or Expired OTP")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let backendError = try? JSONDecoder().decode(BackendErrorBody.self, from: data)
            throw APIError.serverError(backendError?.error ?? "Unable to verify OTP. Please try again.")
        }
    }

    func claimAccount(profileId: UUID, email: String, password: String) async throws -> LoginResponse {
        guard let url = URL(string: "\(baseURL)/auth/claim-cardholder") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = [
            "profile_id": profileId.uuidString,
            "email": email,
            "password": password
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode == 400 || httpResponse.statusCode == 404 {
            let backendError = try? JSONDecoder().decode(BackendErrorBody.self, from: data)
            throw APIError.badRequest(backendError?.error ?? "Unable to claim account. Please check your details.")
        }
        
        if httpResponse.statusCode == 403 || httpResponse.statusCode == 409 {
            let backendError = try? JSONDecoder().decode(BackendErrorBody.self, from: data)
            throw APIError.conflict(backendError?.error ?? "This account cannot be claimed.")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let backendError = try? JSONDecoder().decode(BackendErrorBody.self, from: data)
            throw APIError.serverError(backendError?.error ?? "Unable to complete account creation. Please try again.")
        }
        
        let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
        self.authToken = loginResponse.token
        self.currentUserEmail = loginResponse.user.email
        return loginResponse
    }

    func recordTransaction(
        cardholderId: String,
        originalAmount: Double,
        discountedAmount: Double
    ) async throws -> TransactionRecordResponse {
        guard let url = URL(string: "\(baseURL)/transactions/record") else {
            throw URLError(.badURL)
        }
        guard let token = authToken else {
            throw URLError(.userAuthenticationRequired)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let payload = TransactionRecordRequest(
            cardholderId: cardholderId,
            originalAmount: originalAmount,
            discountedAmount: discountedAmount
        )
        request.httpBody = try JSONEncoder().encode(payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let backendError = try? JSONDecoder().decode(BackendErrorBody.self, from: data)
            throw APIError.serverError(
                backendError?.error ?? "Unable to record transaction. Please try again."
            )
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(TransactionRecordResponse.self, from: data)
    }

    func fetchBusinessTransactions(
        startDate: Date? = nil,
        endDate: Date? = nil
    ) async throws -> [TransactionHistoryItem] {
        var components = URLComponents(string: "\(baseURL)/transactions/business")
        var queryItems: [URLQueryItem] = []

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]

        if let startDate {
            let startOfDay = Calendar.current.startOfDay(for: startDate)
            queryItems.append(URLQueryItem(name: "startDate", value: isoFormatter.string(from: startOfDay)))
        }
        if let endDate {
            let startOfEndDay = Calendar.current.startOfDay(for: endDate)
            let endOfDay = Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: startOfEndDay) ?? endDate
            queryItems.append(URLQueryItem(name: "endDate", value: isoFormatter.string(from: endOfDay)))
        }

        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }

        guard let url = components?.url else {
            throw URLError(.badURL)
        }
        guard let token = authToken else {
            throw URLError(.userAuthenticationRequired)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let backendError = try? JSONDecoder().decode(BackendErrorBody.self, from: data)
            throw APIError.serverError(
                backendError?.error ?? "Unable to fetch business transactions."
            )
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        if let items = try? decoder.decode([TransactionHistoryItem].self, from: data) {
            return items
        }
        let summary = try decoder.decode(BusinessDashboardSummary.self, from: data)
        return summary.transactions ?? []
    }

    func fetchCardholderTransactions(
        token: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil
    ) async throws -> [CardholderTransactionHistoryItem] {
        if let token, !token.isEmpty {
            self.authToken = token
        }
        var components = URLComponents(string: "\(baseURL)/transactions/cardholder")
        var queryItems: [URLQueryItem] = []

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]

        if let startDate {
            let startOfDay = Calendar.current.startOfDay(for: startDate)
            queryItems.append(URLQueryItem(name: "startDate", value: isoFormatter.string(from: startOfDay)))
        }
        if let endDate {
            let startOfEndDay = Calendar.current.startOfDay(for: endDate)
            let endOfDay = Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: startOfEndDay) ?? endDate
            queryItems.append(URLQueryItem(name: "endDate", value: isoFormatter.string(from: endOfDay)))
        }

        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }

        guard let url = components?.url else {
            throw URLError(.badURL)
        }
        guard let activeToken = (token?.isEmpty == false ? token : authToken), !activeToken.isEmpty else {
            throw URLError(.userAuthenticationRequired)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(activeToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let backendError = try? JSONDecoder().decode(BackendErrorBody.self, from: data)
            throw APIError.serverError(
                backendError?.error ?? "Unable to fetch cardholder transactions."
            )
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode([CardholderTransactionHistoryItem].self, from: data)
    }

    func fetchBusinessDashboardSummary(range: String = "24h") async throws -> BusinessDashboardSummary {
        var components = URLComponents(string: "\(baseURL)/transactions/business")
        components?.queryItems = [URLQueryItem(name: "range", value: range)]
        guard let url = components?.url else {
            throw URLError(.badURL)
        }
        guard let token = authToken else {
            throw URLError(.userAuthenticationRequired)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let backendError = try? JSONDecoder().decode(BackendErrorBody.self, from: data)
            throw APIError.serverError(
                backendError?.error ?? "Unable to fetch business dashboard metrics."
            )
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(BusinessDashboardSummary.self, from: data)
    }

    func fetchBusinessProfile() async throws -> BusinessProfile {
        guard let url = URL(string: "\(baseURL)/business/me") else {
            throw URLError(.badURL)
        }
        guard let token = authToken else {
            throw URLError(.userAuthenticationRequired)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let backendError = try? JSONDecoder().decode(BackendErrorBody.self, from: data)
            throw APIError.serverError(
                backendError?.error ?? "Unable to fetch business profile."
            )
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let profile = try decoder.decode(BusinessProfile.self, from: data)
        self.currentBusinessProfile = profile
        return profile
    }

    func updateBusinessProfile(branchName: String, category: String, address: String) async throws -> BusinessProfile {
        guard let url = URL(string: "\(baseURL)/business/profile") else {
            throw URLError(.badURL)
        }
        guard let token = authToken else {
            throw URLError(.userAuthenticationRequired)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let body: [String: String] = [
            "branch_name": branchName.trimmingCharacters(in: .whitespacesAndNewlines),
            "category": category.trimmingCharacters(in: .whitespacesAndNewlines),
            "address": address.trimmingCharacters(in: .whitespacesAndNewlines)
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let backendError = try? JSONDecoder().decode(BackendErrorBody.self, from: data)
            throw APIError.serverError(
                backendError?.error ?? "Unable to update business profile. Please try again."
            )
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let updatedProfile = try decoder.decode(BusinessProfile.self, from: data)
        self.currentBusinessProfile = updatedProfile
        return updatedProfile
    }

    func fetchCardholderProfile(token: String? = nil) async throws -> CardholderProfile {
        if let token, !token.isEmpty {
            self.authToken = token
        }
        guard let activeToken = (token?.isEmpty == false ? token : authToken), !activeToken.isEmpty else {
            throw URLError(.userAuthenticationRequired)
        }
        return try await getCardholderProfile(token: activeToken)
    }

    func updateCardholderProfile(
        token: String? = nil,
        email: String,
        emergencyContactName: String,
        emergencyContactNumber: String
    ) async throws -> CardholderProfile {
        if let token, !token.isEmpty {
            self.authToken = token
        }
        guard let url = URL(string: "\(baseURL)/cardholder/profile") else {
            throw URLError(.badURL)
        }
        guard let activeToken = (token?.isEmpty == false ? token : authToken), !activeToken.isEmpty else {
            throw URLError(.userAuthenticationRequired)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(activeToken)", forHTTPHeaderField: "Authorization")

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let body: [String: String] = [
            "email": trimmedEmail,
            "emergency_contact_name": emergencyContactName.trimmingCharacters(in: .whitespacesAndNewlines),
            "emergency_contact_number": emergencyContactNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if httpResponse.statusCode == 409 {
            let backendError = try? JSONDecoder().decode(BackendErrorBody.self, from: data)
            throw APIError.conflict(
                backendError?.error ?? "This email is already in use by another account."
            )
        }

        if httpResponse.statusCode == 400 {
            let backendError = try? JSONDecoder().decode(BackendErrorBody.self, from: data)
            throw APIError.badRequest(
                backendError?.error ?? "Please enter a valid email address and contact details."
            )
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let backendError = try? JSONDecoder().decode(BackendErrorBody.self, from: data)
            throw APIError.serverError(
                backendError?.error ?? "Unable to update cardholder profile. Please try again."
            )
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let updatedProfile = try decoder.decode(CardholderProfile.self, from: data)
        self.currentCardholderProfile = updatedProfile
        if let verifiedEmail = updatedProfile.email, !verifiedEmail.isEmpty {
            self.currentUserEmail = verifiedEmail
        } else if updatedProfile.requiresEmailVerification != true {
            self.currentUserEmail = trimmedEmail
        }
        return updatedProfile
    }

    func verifyCardholderEmailChange(
        token: String? = nil,
        pendingEmail: String,
        otp: String
    ) async throws -> CardholderProfile {
        if let token, !token.isEmpty {
            self.authToken = token
        }
        guard let url = URL(string: "\(baseURL)/cardholder/verify-email-change") else {
            throw URLError(.badURL)
        }
        guard let activeToken = (token?.isEmpty == false ? token : authToken), !activeToken.isEmpty else {
            throw URLError(.userAuthenticationRequired)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(activeToken)", forHTTPHeaderField: "Authorization")

        let trimmedEmail = pendingEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedOTP = otp.trimmingCharacters(in: .whitespacesAndNewlines)
        let body: [String: String] = [
            "pending_email": trimmedEmail,
            "email": trimmedEmail,
            "otp": trimmedOTP
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if httpResponse.statusCode == 400 {
            let backendError = try? JSONDecoder().decode(BackendErrorBody.self, from: data)
            throw APIError.badRequest(
                backendError?.error ?? "Invalid or Expired OTP"
            )
        }

        if httpResponse.statusCode == 409 {
            let backendError = try? JSONDecoder().decode(BackendErrorBody.self, from: data)
            throw APIError.conflict(
                backendError?.error ?? "This email is already in use by another account."
            )
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let backendError = try? JSONDecoder().decode(BackendErrorBody.self, from: data)
            throw APIError.serverError(
                backendError?.error ?? "Unable to verify email change. Please try again."
            )
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let verifiedProfile = try decoder.decode(CardholderProfile.self, from: data)
        self.currentCardholderProfile = verifiedProfile
        self.currentUserEmail = verifiedProfile.email ?? trimmedEmail
        return verifiedProfile
    }

    func resendCardholderEmailChangeOTP(
        token: String? = nil,
        pendingEmail: String
    ) async throws {
        if let token, !token.isEmpty {
            self.authToken = token
        }
        guard let url = URL(string: "\(baseURL)/cardholder/resend-email-change-otp") else {
            throw URLError(.badURL)
        }
        guard let activeToken = (token?.isEmpty == false ? token : authToken), !activeToken.isEmpty else {
            throw URLError(.userAuthenticationRequired)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(activeToken)", forHTTPHeaderField: "Authorization")

        let trimmedEmail = pendingEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let body: [String: String] = [
            "pending_email": trimmedEmail,
            "email": trimmedEmail
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if httpResponse.statusCode == 400 {
            let backendError = try? JSONDecoder().decode(BackendErrorBody.self, from: data)
            throw APIError.badRequest(
                backendError?.error ?? "Please enter a valid email address."
            )
        }

        if httpResponse.statusCode == 409 {
            let backendError = try? JSONDecoder().decode(BackendErrorBody.self, from: data)
            throw APIError.conflict(
                backendError?.error ?? "This email is already in use by another account."
            )
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let backendError = try? JSONDecoder().decode(BackendErrorBody.self, from: data)
            throw APIError.serverError(
                backendError?.error ?? "Failed to send verification code. Please try again."
            )
        }
    }

    func changePassword(
        token: String = "",
        currentPassword: String,
        newPassword: String
    ) async throws {
        let resolvedToken = token.isEmpty ? (self.authToken ?? "") : token
        if !resolvedToken.isEmpty {
            self.authToken = resolvedToken
        }
        guard let url = URL(string: "\(baseURL)/auth/change-password") else {
            throw URLError(.badURL)
        }
        guard !resolvedToken.isEmpty else {
            throw URLError(.userAuthenticationRequired)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(resolvedToken)", forHTTPHeaderField: "Authorization")

        let body: [String: String] = [
            "current_password": currentPassword,
            "new_password": newPassword
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if httpResponse.statusCode == 400 || httpResponse.statusCode == 401 {
            let backendError = try? JSONDecoder().decode(BackendErrorBody.self, from: data)
            throw APIError.badRequest(
                backendError?.error ?? "Unable to change password. Please verify your current password."
            )
        }

        if httpResponse.statusCode == 403 || httpResponse.statusCode == 409 {
            let backendError = try? JSONDecoder().decode(BackendErrorBody.self, from: data)
            throw APIError.conflict(
                backendError?.error ?? "Unable to change password."
            )
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let backendError = try? JSONDecoder().decode(BackendErrorBody.self, from: data)
            throw APIError.serverError(
                backendError?.error ?? "Unable to update password. Please try again."
            )
        }
    }

}


