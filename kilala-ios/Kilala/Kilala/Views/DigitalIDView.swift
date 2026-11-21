//
//  DigitalIDView.swift
//  Kilala
//
//  Created by Joshua Calibo on 10/22/26.
//

import SwiftUI

struct DigitalIDView: View {
    let token: String
    let onLogout: () -> Void
    
    var body: some View {
        CardholderDashboardView(token: token, onLogout: onLogout)
    }
}
