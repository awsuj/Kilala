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
                    
                    NavigationLink(destination: BusinessTransactionHistoryView()) {
                        HStack(spacing: 8) {
                            Image(systemName: "clock.arrow.circlepath")
                            Text("View Transaction History")
                                .fontWeight(.semibold)
                        }
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                    }
                    .padding(.bottom, 8)
                    
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
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink(destination: BusinessTransactionHistoryView()) {
                        Label("History", systemImage: "clock.arrow.circlepath")
                    }
                }
                if let onLogout = onLogout {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Logout", action: onLogout)
                    }
                }
            }
            .onAppear {
                APIService.shared.authToken = token
            }
            .sheet(item: $scanResult) { result in
                ScanResultSheet(result: result) {
                    scanResult = nil
                }
                .presentationDetents([.large, .medium])
                .presentationDragIndicator(.visible)
            }
        }
    }
    
    private func verifyQRToken(_ qrToken: String) {
        let trimmedToken = qrToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty && !isVerifying && scanResult == nil else { return }
        
        isVerifying = true
        errorMessage = nil
        
        Task {
            do {
                let response = try await APIService.shared.verifyScan(qrToken: trimmedToken, token: token)
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
