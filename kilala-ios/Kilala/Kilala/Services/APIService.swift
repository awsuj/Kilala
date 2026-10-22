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

class APIService {
    static let shared = APIService()
    
    // IMPORTANT: If running on a physical iPhone, change "localhost" to your Mac's IPv4 address (e.g., "192.168.1.15")
    private let baseURL = "http://localhost:5001/api"
    
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
        return loginResponse
    }
}

