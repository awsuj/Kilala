//
//  QRScannerView.swift
//  Kilala
//
//  Created by Joshua Calibo on 10/22/26.
//

import SwiftUI
import AVFoundation

struct QRScannerView: View {
    let token: String
    var onLogout: (() -> Void)? = nil
    
    @State private var scanResult: VerificationResponse? = nil
    @State private var isVerifying = false
    @State private var errorMessage: String? = nil
    
    #if targetEnvironment(simulator)
    @State private var manualQRToken = ""
    #endif
    
    private var isScannerActive: Bool {
        !isVerifying && scanResult == nil
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Camera Feed Background
                QRCameraScannerRepresentable(isScanning: isScannerActive) { scannedToken in
                    verifyQRToken(scannedToken)
                }
                .ignoresSafeArea()
                
                // Darkened Scanner Overlay & Reticle
                VStack(spacing: 24) {
                    VStack(spacing: 6) {
                        Text("Scan Kilala Digital ID")
                            .font(.title3.bold())
                            .foregroundColor(.white)
                        
                        Text("Align the cardholder's QR code within the frame")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .padding(.top, 16)
                    
                    Spacer()
                    
                    // Scanner Reticle Frame
                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(
                                isVerifying ? Color.yellow : Color.white,
                                style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [30, 15])
                            )
                            .frame(width: 260, height: 260)
                            .background(Color.black.opacity(0.15).cornerRadius(24))
                        
                        if isVerifying {
                            VStack(spacing: 12) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.3)
                                Text("Verifying ID...")
                                    .font(.callout.weight(.semibold))
                                    .foregroundColor(.white)
                            }
                            .padding(20)
                            .background(.ultraThinMaterial)
                            .cornerRadius(16)
                        }
                    }
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.footnote.weight(.medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.red.opacity(0.9))
                            .cornerRadius(10)
                            .padding(.horizontal)
                    }
                    
                    Spacer()
                    
                    #if targetEnvironment(simulator)
                    // Simulator Fallback for testing without a physical camera
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Simulator Debug Input", systemImage: "hammer.fill")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 10) {
                            TextField("Paste QR token (e.g. KILALA-QR-...)", text: $manualQRToken)
                                .textFieldStyle(.roundedBorder)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .font(.system(.subheadline, design: .monospaced))
                            
                            Button {
                                let trimmed = manualQRToken.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !trimmed.isEmpty else { return }
                                verifyQRToken(trimmed)
                            } label: {
                                Text("Verify")
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                            .disabled(isVerifying || manualQRToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    .padding()
                    .background(.regularMaterial)
                    .cornerRadius(16)
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                    #endif
                }
            }
            .navigationTitle("Merchant Scanner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let onLogout = onLogout {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Logout", action: onLogout)
                    }
                }
            }
            .sheet(item: $scanResult) { result in
                ScanResultSheet(result: result) {
                    scanResult = nil
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }
    
    private func verifyQRToken(_ qrToken: String) {
        guard !isVerifying && scanResult == nil else { return }
        
        isVerifying = true
        errorMessage = nil
        
        Task {
            do {
                let response = try await APIService.shared.verifyScan(qrToken: qrToken, token: token)
                let feedback = UINotificationFeedbackGenerator()
                feedback.notificationOccurred(response.isValid ? .success : .error)
                isVerifying = false
                scanResult = response
            } catch {
                let feedback = UINotificationFeedbackGenerator()
                feedback.notificationOccurred(.error)
                isVerifying = false
                errorMessage = "Unable to verify QR code. Check your connection or business accreditation."
            }
        }
    }
}

// MARK: - Scan Result Sheet

struct ScanResultSheet: View {
    let result: VerificationResponse
    let onDismiss: () -> Void
    
    private var themeColor: Color {
        result.isValid ? .green : .red
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Status Banner Header
                    VStack(spacing: 10) {
                        Image(systemName: result.isValid ? "checkmark.seal.fill" : "xmark.octagon.fill")
                            .font(.system(size: 56))
                            .foregroundColor(.white)
                        
                        Text(result.isValid ? "VERIFIED" : "INVALID / REVOKED")
                            .font(.title2.weight(.heavy))
                            .tracking(1)
                            .foregroundColor(.white)
                        
                        Text(result.message)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.white.opacity(0.95))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .padding(.horizontal, 16)
                    .background(themeColor.gradient)
                    .cornerRadius(20)
                    
                    // Cardholder Details Card
                    if let cardholder = result.cardholderSummary {
                        VStack(spacing: 16) {
                            // Cardholder Photo & Primary Identity
                            HStack(spacing: 16) {
                                CardholderAvatarView(photoUrl: cardholder.photoUrl, borderColor: themeColor)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(cardholder.fullName)
                                        .font(.title3.bold())
                                        .foregroundColor(.primary)
                                    
                                    Text(cardholder.lguName.uppercased())
                                        .font(.caption.weight(.bold))
                                        .foregroundColor(.secondary)
                                    
                                    Text(cardholder.lguIdNumber)
                                        .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                                        .foregroundColor(themeColor)
                                }
                                
                                Spacer()
                            }
                            
                            Divider()
                            
                            // Metadata Rows
                            VStack(spacing: 10) {
                                DetailRow(label: "LGU", value: cardholder.lguName)
                                DetailRow(label: "ID Number", value: cardholder.lguIdNumber)
                                DetailRow(
                                    label: "Privilege Type",
                                    value: cardholder.privilegeType.replacingOccurrences(of: "_", with: " ")
                                )
                                
                                if let disabilityType = cardholder.disabilityType, !disabilityType.isEmpty {
                                    DetailRow(label: "Disability Type", value: disabilityType)
                                }
                                
                                DetailRow(label: "Card Status", value: cardholder.status, valueColor: themeColor)
                            }
                        }
                        .padding(18)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(themeColor.opacity(0.35), lineWidth: 1.5)
                        )
                    } else {
                        // Unrecognized / Counterfeit QR Code Fallback
                        VStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.largeTitle)
                                .foregroundColor(.red)
                            
                            Text("No Matching Cardholder Record")
                                .font(.headline)
                            
                            Text("This QR code is not registered in the Kilala database or has been rotated by the cardholder. Do not honor mandatory discount privileges for this scan.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(16)
                    }
                    
                    Button(action: onDismiss) {
                        Text(result.isValid ? "Scan Next Customer" : "Dismiss & Scan Again")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(themeColor)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .padding(.top, 4)
                }
                .padding()
            }
            .navigationTitle("Verification Result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done", action: onDismiss)
                }
            }
        }
    }
}

private struct CardholderAvatarView: View {
    let photoUrl: String?
    let borderColor: Color
    
    var body: some View {
        Group {
            if let photoUrl = photoUrl,
               !photoUrl.isEmpty,
               let url = URL(string: photoUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        placeholderIcon
                    case .empty:
                        ProgressView()
                    @unknown default:
                        placeholderIcon
                    }
                }
            } else {
                placeholderIcon
            }
        }
        .frame(width: 72, height: 72)
        .background(Color(.tertiarySystemBackground))
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(borderColor, lineWidth: 2.5)
        )
    }
    
    private var placeholderIcon: some View {
        Image(systemName: "person.crop.circle.fill")
            .resizable()
            .scaledToFit()
            .foregroundColor(.secondary)
            .padding(6)
    }
}

private struct DetailRow: View {
    let label: String
    let value: String
    var valueColor: Color = .primary
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(valueColor)
        }
    }
}

// MARK: - AVFoundation Camera Preview

struct QRCameraScannerRepresentable: UIViewControllerRepresentable {
    let isScanning: Bool
    let onCodeScanned: (String) -> Void
    
    func makeUIViewController(context: Context) -> ScannerViewController {
        let controller = ScannerViewController()
        controller.onCodeScanned = onCodeScanned
        controller.isScanningEnabled = isScanning
        return controller
    }
    
    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {
        uiViewController.onCodeScanned = onCodeScanned
        uiViewController.isScanningEnabled = isScanning
    }
}

final class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCodeScanned: ((String) -> Void)?
    var isScanningEnabled: Bool = true
    
    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCaptureSession()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }
    
    private func setupCaptureSession() {
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            return
        }
        
        guard let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice),
              captureSession.canAddInput(videoInput) else {
            return
        }
        captureSession.addInput(videoInput)
        
        let metadataOutput = AVCaptureMetadataOutput()
        guard captureSession.canAddOutput(metadataOutput) else {
            return
        }
        captureSession.addOutput(metadataOutput)
        
        metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        metadataOutput.metadataObjectTypes = [.qr]
        
        let preview = AVCaptureVideoPreviewLayer(session: captureSession)
        preview.frame = view.layer.bounds
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)
        self.previewLayer = preview
        
        let session = captureSession
        DispatchQueue.global(qos: .userInitiated).async {
            if !session.isRunning {
                session.startRunning()
            }
        }
    }
    
    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let readableObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let stringValue = readableObject.stringValue else {
            return
        }
        
        Task { @MainActor [weak self] in
            guard let self = self, self.isScanningEnabled else { return }
            self.isScanningEnabled = false
            self.onCodeScanned?(stringValue)
        }
    }
}
