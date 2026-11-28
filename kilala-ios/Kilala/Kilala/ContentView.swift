//
//  ContentView.swift
//  Kilala
//
//  Created by Joshua Calibo on 10/21/26.
//

import SwiftUI

@MainActor
struct ContentView: View {
    @ObservedObject var sessionManager: SessionManager

    init(sessionManager: SessionManager = .shared) {
        self.sessionManager = sessionManager
    }

    var body: some View {
        Group {
            if let session = sessionManager.session {
                switch session.user.role {
                case .cardholder:
                    CardholderDashboardView(token: session.token) {
                        sessionManager.logout()
                    }
                case .business:
                    BusinessDashboardView(token: session.token, userEmail: session.user.email) {
                        sessionManager.logout()
                    }
                case .lguAdmin, .superAdmin:
                    VStack(spacing: 16) {
                        Text("Please use the Kilala Web Portal for LGU Admin access.")
                            .foregroundColor(.kilalaInk)
                            .multilineTextAlignment(.center)
                        Button("Logout") {
                            sessionManager.logout()
                        }
                    }
                    .padding()
                }
            } else {
                LoginView { loginResponse in
                    sessionManager.saveSession(loginResponse)
                }
            }
        }
        .task {
            await sessionManager.refreshRestoredSessionIfNeeded()
        }
    }
}
