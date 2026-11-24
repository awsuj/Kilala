//
//  QRScannerView.swift
//  Kilala
//
//  Created by Joshua Calibo on 10/22/26.
//

import SwiftUI
import UIKit
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
    @State private var rawDetectionStatus: String? = nil
    
    #if targetEnvironment(simulator)
    @State private var manualQRToken = ""
    #endif
    
    private var isScannerActive: Bool {
        isScannerVisible && !isVerifying && scanResult == nil
    }
    
    private var statusBannerText: String {
        rawDetectionStatus ?? "Align the cardholder's QR code within the frame"
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
            QRCameraScannerRepresentable(
                isScanning: isScannerActive,
                onRawCodeDetected: {
                    errorMessage = nil
                    rawDetectionStatus = "Verifying QR..."
                },
                onCodeScanned: { scannedToken in
                    verifyQRToken(scannedToken)
                }
            )
            .ignoresSafeArea()
            
            // Darkened Scanner Overlay & Reticle
            VStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("Scan Kilala Digital ID")
                        .font(.kilala(.title3, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(statusBannerText)
                        .font(.kilala(.subheadline, weight: rawDetectionStatus != nil ? .semibold : .regular))
                        .foregroundColor(rawDetectionStatus != nil ? .kilalaSunrise : .white.opacity(0.9))
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
        guard !trimmedToken.isEmpty && !isVerifying && scanResult == nil else {
            rawDetectionStatus = nil
            return
        }
        
        isVerifying = true
        rawDetectionStatus = "Verifying QR..."
        errorMessage = nil
        
        Task {
            do {
                let response = try await APIService.shared.verifyScan(qrToken: trimmedToken, token: token)
                let feedback = UINotificationFeedbackGenerator()
                feedback.notificationOccurred(response.isValid ? .success : .error)
                isVerifying = false
                rawDetectionStatus = nil
                scanResult = response
            } catch {
                let feedback = UINotificationFeedbackGenerator()
                feedback.notificationOccurred(.error)
                isVerifying = false
                rawDetectionStatus = nil
                errorMessage = "Unable to verify QR code. Check your connection or business accreditation."
            }
        }
    }
}

// MARK: - AVFoundation Camera Preview

struct QRCameraScannerRepresentable: UIViewRepresentable {
    let isScanning: Bool
    let onRawCodeDetected: () -> Void
    let onCodeScanned: (String) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            isScanningEnabled: isScanning,
            onRawCodeDetected: onRawCodeDetected,
            onCodeScanned: onCodeScanned
        )
    }
    
    func makeUIView(context: Context) -> CameraPreviewView {
        let previewView = CameraPreviewView()
        previewView.backgroundColor = .black
        previewView.previewLayer.session = context.coordinator.captureSession
        previewView.previewLayer.videoGravity = .resizeAspectFill
        context.coordinator.configureAndStartIfNeeded()
        return previewView
    }
    
    func updateUIView(_ uiView: CameraPreviewView, context: Context) {
        // Only update scan gating and callbacks — never reconfigure or restart the running AVCaptureSession.
        context.coordinator.onRawCodeDetected = onRawCodeDetected
        context.coordinator.onCodeScanned = onCodeScanned
        context.coordinator.isScanningEnabled = isScanning
    }
    
    static func dismantleUIView(_ uiView: CameraPreviewView, coordinator: Coordinator) {
        coordinator.stopSession()
    }
    
    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        let captureSession = AVCaptureSession()
        private let sessionQueue = DispatchQueue(label: "com.kilala.qrscanner.session")
        private var isSessionConfigured = false
        
        var isScanningEnabled: Bool
        var onRawCodeDetected: () -> Void
        var onCodeScanned: (String) -> Void
        
        init(
            isScanningEnabled: Bool,
            onRawCodeDetected: @escaping () -> Void,
            onCodeScanned: @escaping (String) -> Void
        ) {
            self.isScanningEnabled = isScanningEnabled
            self.onRawCodeDetected = onRawCodeDetected
            self.onCodeScanned = onCodeScanned
            super.init()
        }
        
        func configureAndStartIfNeeded() {
            guard !isSessionConfigured else {
                startRunningIfNeeded()
                return
            }
            
            guard let videoCaptureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
                    ?? AVCaptureDevice.default(for: .video) else {
                return
            }
            
            guard let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice) else {
                return
            }
            
            if videoCaptureDevice.isFocusModeSupported(.continuousAutoFocus) {
                try? videoCaptureDevice.lockForConfiguration()
                videoCaptureDevice.focusMode = .continuousAutoFocus
                videoCaptureDevice.unlockForConfiguration()
            }
            
            captureSession.beginConfiguration()
            
            guard captureSession.canAddInput(videoInput) else {
                captureSession.commitConfiguration()
                return
            }
            captureSession.addInput(videoInput)
            
            let metadataOutput = AVCaptureMetadataOutput()
            guard captureSession.canAddOutput(metadataOutput) else {
                captureSession.commitConfiguration()
                return
            }
            // Add output BEFORE setting metadataObjectTypes, and attach retained Coordinator on .main queue.
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
            if metadataOutput.availableMetadataObjectTypes.contains(.qr) {
                metadataOutput.metadataObjectTypes = [.qr]
            }
            // Do not set metadataOutput.rectOfInterest so the entire camera frame is scanned.
            
            captureSession.commitConfiguration()
            isSessionConfigured = true
            
            startRunningIfNeeded()
        }
        
        private func startRunningIfNeeded() {
            let session = captureSession
            sessionQueue.async {
                if !session.isRunning {
                    session.startRunning()
                }
            }
        }
        
        func stopSession() {
            let session = captureSession
            sessionQueue.async {
                if session.isRunning {
                    session.stopRunning()
                }
            }
        }
        
        nonisolated func metadataOutput(
            _ output: AVCaptureMetadataOutput,
            didOutput metadataObjects: [AVMetadataObject],
            from connection: AVCaptureConnection
        ) {
            guard let readableObject = metadataObjects
                .compactMap({ $0 as? AVMetadataMachineReadableCodeObject })
                .first(where: { $0.stringValue?.isEmpty == false }),
                  let stringValue = readableObject.stringValue else {
                return
            }
            
            MainActor.assumeIsolated {
                guard self.isScanningEnabled else { return }
                self.isScanningEnabled = false
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                self.onRawCodeDetected()
                self.onCodeScanned(stringValue)
            }
        }
    }
}

final class CameraPreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }
    
    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}
