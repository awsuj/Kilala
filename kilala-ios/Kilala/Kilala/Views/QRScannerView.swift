//
//  QRScannerView.swift
//  Kilala
//
//  Created by Joshua Calibo on 10/22/26.
//

import SwiftUI
import AVFoundation

struct QRScannerView: View {
    var token: String = APIService.shared.authToken ?? ""
    var onLogout: (() -> Void)? = nil
    var isEmbeddedInDrawer: Bool = false
    var isScannerVisible: Bool = true
    var onTransactionRecorded: (() -> Void)? = nil
    
    @State private var scanResult: VerificationResponse? = nil
    @State private var isVerifying = false
    @State private var errorMessage: String? = nil
    
    #if targetEnvironment(simulator)
    @State private var manualQRToken = ""
    #endif
    
    private var isScannerActive: Bool {
        isScannerVisible && !isVerifying && scanResult == nil
    }
    
    var body: some View {
        Group {
            if isEmbeddedInDrawer {
                scannerContent
            } else {
                NavigationStack {
                    scannerContent
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
                }
            }
        }
        .onAppear {
            if !token.isEmpty {
                APIService.shared.authToken = token
            }
        }
        .sheet(item: $scanResult) { result in
            ScanResultSheet(result: result) {
                scanResult = nil
                onTransactionRecorded?()
            }
            .presentationDetents([.large, .medium])
            .presentationDragIndicator(.visible)
        }
    }
    
    private var scannerContent: some View {
        ZStack {
            // Camera Feed Background
            QRCameraScannerRepresentable(isScanning: isScannerActive) { scannedToken in
                verifyQRToken(scannedToken)
            }
            .ignoresSafeArea()
            
            // Darkened Scanner Overlay & Reticle
            VStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("Scan Kilala Digital ID")
                        .font(.kilala(.title3, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Align the cardholder's QR code within the frame")
                        .font(.kilala(.subheadline))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.top, 12)
                
                Spacer()
                
                // Scanner Reticle Frame (16pt restrained radius)
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            isVerifying ? Color.kilalaSunrise : Color.white,
                            style: StrokeStyle(lineWidth: 3.5, lineCap: .round, dash: [28, 14])
                        )
                        .frame(width: 240, height: 240)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.kilalaInk.opacity(0.20))
                        )
                    
                    if isVerifying {
                        VStack(spacing: 12) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .kilalaSunrise))
                                .scaleEffect(1.2)
                            Text("Verifying ID...")
                                .font(.kilala(.callout, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(16)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                
                if let errorMessage = errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .accessibilityHidden(true)

                        Text(errorMessage)
                            .font(.kilala(.footnote, weight: .semibold))
                            .foregroundColor(.white)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.kilalaStateInvalid.opacity(0.95))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal, 16)
                }
                
                Spacer()
                
                if !isEmbeddedInDrawer {
                    NavigationLink(destination: BusinessTransactionHistoryView()) {
                        HStack(spacing: 8) {
                            Image(systemName: "clock.arrow.circlepath")
                            Text("View Transaction History")
                                .font(.kilala(.subheadline, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 48)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .padding(.bottom, 8)
                }
                
                #if targetEnvironment(simulator)
                // Simulator Fallback for testing without a physical camera
                VStack(alignment: .leading, spacing: 12) {
                    Label("Simulator Debug Input", systemImage: "hammer.fill")
                        .font(.kilala(.caption, weight: .bold))
                        .foregroundColor(.kilalaInkSecondary)
                    
                    HStack(spacing: 8) {
                        TextField("Paste QR token (e.g. KILALA-QR-...)", text: $manualQRToken)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.kilalaMono(.callout, weight: .medium))
                            .foregroundColor(.kilalaInk)
                            .tint(.kilalaGreen)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 48)
                            .background(Color.kilalaPaper)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.kilalaBorder, lineWidth: 1)
                            )
                        
                        Button {
                            let trimmed = manualQRToken.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }
                            verifyQRToken(trimmed)
                        } label: {
                            Text("Verify")
                                .font(.kilala(.callout, weight: .bold))
                                .padding(.horizontal, 16)
                                .frame(minHeight: 48)
                                .background(Color.kilalaGreen)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .disabled(isVerifying || manualQRToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding(16)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.kilalaMintBorder, lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                #endif
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
