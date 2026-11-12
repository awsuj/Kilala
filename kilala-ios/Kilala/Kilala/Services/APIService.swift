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

enum APIError: LocalizedError {
    case conflict(String)
    case badRequest(String)
    case unauthorized(String)
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .conflict(let message),
             .badRequest(let message),
             .unauthorized(let message),
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
    
    // IMPORTANT: If running on a physical iPhone, change "localhost" to your Mac's IPv4 address (e.g., "192.168.1.15")
    private let baseURL =  "http://localhost:5001/api" //http://address:5001/api"
    var authToken: String?
    
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
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        // Map HTTP errors to messages the login screen can show as-is.
        // Network failures (server down, no internet) are thrown by URLSession as URLError.
        guard (200...299).contains(httpResponse.statusCode) else {
            let backendMessage = (try? JSONDecoder().decode(BackendErrorBody.self, from: data))?.error
            switch httpResponse.statusCode {
            case 400:
                throw APIError.badRequest(backendMessage ?? "Email and password are required.")
            case 401, 403:
                throw APIError.unauthorized(backendMessage ?? "Invalid email or password.")
            default:
                throw APIError.serverError("The Kilala server had a problem. Please try again later.")
            }
        }

        // Decode the successful JSON response
        let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
        self.authToken = loginResponse.token
        return loginResponse
    }
    
    func getCardholderProfile(token: String) async throws -> CardholderProfile {
        self.authToken = token
        guard let url = URL(string: "\(baseURL)/cardholder/me") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(CardholderProfile.self, from: data)
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

    /// Creates the cardholder's login for an LGU record that was matched with `verifyRecord`.
    /// On success the backend returns the same shape as login, so the user is signed in right away.
    func claimCardholder(
        lguIdNumber: String,
        dateOfBirth: String,
        email: String,
        password: String
    ) async throws -> LoginResponse {
        guard let url = URL(string: "\(baseURL)/auth/claim-cardholder") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "lgu_id_number": lguIdNumber,
            "date_of_birth": dateOfBirth,
            "email": email,
            "password": password
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let backendMessage = (try? JSONDecoder().decode(BackendErrorBody.self, from: data))?.error
            switch httpResponse.statusCode {
            case 400, 404:
                throw APIError.badRequest(backendMessage ?? "Unable to match your LGU record. Please check your details.")
            case 409:
                throw APIError.conflict(backendMessage ?? "This ID or email is already linked to an account.")
            default:
                throw APIError.serverError(backendMessage ?? "Unable to create your account. Please try again.")
            }
        }

        let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
        self.authToken = loginResponse.token
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

    func fetchBusinessTransactions() async throws -> [TransactionHistoryItem] {
        guard let url = URL(string: "\(baseURL)/transactions/business") else {
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
        return try decoder.decode([TransactionHistoryItem].self, from: data)
    }

}


