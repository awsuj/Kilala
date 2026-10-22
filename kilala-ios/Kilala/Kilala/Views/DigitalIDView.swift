//
//  DigitalIDView.swift
//  Kilala
//
//  Created by Joshua Calibo on 10/22/26.
//

import SwiftUI
import CoreImage.CIFilterBuiltins

struct DigitalIDView: View {
    let token: String
    let onLogout: () -> Void
    
    @State private var profile: CardholderProfile?
    @State private var errorMessage: String?
    
    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let profile = profile {
                    // Digital ID Card
                    VStack(spacing: 12) {
                        Text(profile.lguName.uppercased())
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                        
                        Text(profile.fullName)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("\(profile.privilegeType) • \(profile.lguIdNumber)")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        
                        if let disability = profile.disabilityType {
                            Text(disability)
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                        
                        // QR Code Image
                        Image(uiImage: generateQRCode(from: profile.qrSecretToken))
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 220, height: 220)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(radius: 4)
                        
                        Text("Status: \(profile.status)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(profile.status == "ACTIVE" ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                            .foregroundColor(profile.status == "ACTIVE" ? .green : .red)
                            .cornerRadius(8)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .padding()
                } else if let errorMessage = errorMessage {
                    Text(errorMessage).foregroundColor(.red)
                } else {
                    ProgressView("Loading Digital ID...")
                }
            }
            .navigationTitle("My Kilala ID")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Logout", action: onLogout)
                }
            }
            .task {
                await loadProfile()
            }
        }
    }
    
    private func loadProfile() async {
        do {
            profile = try await APIService.shared.getCardholderProfile(token: token)
        } catch {
            errorMessage = "Could not load Digital ID."
        }
    }
    
    private func generateQRCode(from string: String) -> UIImage {
        filter.message = Data(string.utf8)
        if let outputImage = filter.outputImage,
           let cgImage = context.createCGImage(outputImage, from: outputImage.extent) {
            return UIImage(cgImage: cgImage)
        }
        return UIImage(systemName: "xmark.circle") ?? UIImage()
    }
}
