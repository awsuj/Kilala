//
//  KilalaApp.swift
//  Kilala
//
//  Created by Joshua Calibo on 10/21/26.
//

import SwiftUI

@main
struct KilalaApp: App {
    @StateObject private var sessionManager = SessionManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView(sessionManager: sessionManager)
                .preferredColorScheme(.light)
        }
    }
}
