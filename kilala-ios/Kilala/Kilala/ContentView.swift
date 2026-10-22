//
//  ContentView.swift
//  Kilala
//
//  Created by Joshua Calibo on 10/21/26.
//

import SwiftUI

struct ContentView: View {
    @State private var session: LoginResponse? = nil
    
    var body: some View {
        if let session = session {
            switch session.user.role {
            case .cardholder:
                DigitalIDView(token: session.token) {
                    self.session = nil
                }
            case .business:
                VStack(spacing: 16) {
                    Text("Business Scanner Portal")
                        .font(.title2.bold())
                    Text("Logged in as: \(session.user.email)")
                    Button("Logout") { self.session = nil }
                }
            case .lguAdmin:
                VStack(spacing: 16) {
                    Text("Please use the Kilala Web Portal for LGU Admin access.")
                        .multilineTextAlignment(.center)
                    Button("Logout") { self.session = nil }
                }
                .padding()
            }
        } else {
            LoginView { loginResponse in
                self.session = loginResponse
            }
        }
    }
}
