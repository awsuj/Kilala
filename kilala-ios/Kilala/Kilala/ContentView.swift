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
                    APIService.shared.authToken = nil
                    self.session = nil
                }
            case .business:
                QRScannerView(token: session.token) {
                    APIService.shared.authToken = nil
                    self.session = nil
                }
            case .lguAdmin:
                VStack(spacing: 16) {
                    Text("Please use the Kilala Web Portal for LGU Admin access.")
                        .multilineTextAlignment(.center)
                    Button("Logout") {
                        APIService.shared.authToken = nil
                        self.session = nil
                    }
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
