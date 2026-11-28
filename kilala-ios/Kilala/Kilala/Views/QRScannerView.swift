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
    var onClose: (() -> Void)? = nil
    var onTransactionRecorded: (() -> Void)? = nil

    @State private var scanResult: VerificationResponse? = nil
    @State private var isVerifying = false
    @State private var errorMessage: String? = nil
    @State private var rawDetectionStatus: String? = nil
    @State private var manualQRToken: String = ""
    @State private var isShowingManualInput: Bool = false

    // Shared exact viewfinder geometry for both cutout mask and corner brackets
    private static let scanBoxSize: CGFloat = 260
    private static let scanBoxCornerRadius: CGFloat = 24

    private var isScannerActive: Bool {
        isScannerVisible && !isVerifying && scanResult == nil && !isShowingManualInput
    }

    private var statusBannerText: String {
        rawDetectionStatus ?? "Align Kilala QR code inside the frame"
    }

    var body: some View {
        Group {
            if isEmbeddedInDrawer {
                scannerContent
            } else {
                NavigationStack {
                    scannerContent
                        .toolbar(.hidden, for: .navigationBar)
                }
            }
        }
        .onAppear {
            if !token.isEmpty {
                APIService.shared.authToken = token
            }
        }
        .sheet(isPresented: $isShowingManualInput) {
            ManualQRInputSheet(
                manualQRToken: $manualQRToken,
                isVerifying: isVerifying,
                onVerify: { code in
                    isShowingManualInput = false
                    verifyQRToken(code)
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(16)
            .presentationBackground(Color.kilalaPaper)
        }
        .sheet(item: $scanResult, onDismiss: {
            manualQRToken = ""
            isVerifying = false
            rawDetectionStatus = nil
        }) { result in
            ScanResultSheet(
                result: result,
                manualQRToken: $manualQRToken
            ) {
                manualQRToken = ""
                isVerifying = false
                rawDetectionStatus = nil
                scanResult = nil
                onTransactionRecorded?()
            }
            .presentationDetents([.large, .medium])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Top Header Bar (Mathematically Centered Title + Matching 36pt Pills)

    private var topHeaderBar: some View {
        ZStack {
            Text("Scan QR")
                .font(.kilala(.headline, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)

            HStack(alignment: .center) {
                if let onClose = onClose {
                    Button(action: onClose) {
                        Text("Close")
                            .font(.kilala(.footnote, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .frame(height: 36)
                            .background(Color.kilalaInk.opacity(0.65))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                } else if !isEmbeddedInDrawer {
                    NavigationLink(destination: BusinessTransactionHistoryView()) {
                        HStack(spacing: 5) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 13, weight: .semibold))
                                .accessibilityHidden(true)

                            Text("History")
                                .font(.kilala(.footnote, weight: .bold))
                                .lineLimit(1)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .frame(height: 36)
                        .background(Color.kilalaInk.opacity(0.65))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                manualInputPillButton
            }
        }
        .frame(height: 44)
        .padding(.horizontal, 16)
    }

    private var manualInputPillButton: some View {
        Button {
            errorMessage = nil
            isShowingManualInput = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "keyboard")
                    .font(.system(size: 13, weight: .semibold))
                    .accessibilityHidden(true)

                Text("Manual Input")
                    .font(.kilala(.footnote, weight: .bold))
                    .lineLimit(1)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(Color.kilalaInk.opacity(0.65))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isVerifying)
        .accessibilityLabel("Manual QR Input")
    }

    // MARK: - Scanner Viewfinder & Overlay

    private var scannerContent: some View {
        ZStack {
            // Layer 1: Live Full-Bleed Camera Feed
            QRCameraScannerRepresentable(
                isScanning: isScannerActive,
                onRawCodeDetected: {
                    errorMessage = nil
                    rawDetectionStatus = "QR Detected — Verifying..."
                },
                onCodeScanned: { scannedToken in
                    verifyQRToken(scannedToken)
                }
            )
            .ignoresSafeArea()

            // Layer 2: Centered 260x260 Cutout Mask + Exact Co-Centered Corner Brackets
            ZStack(alignment: .center) {
                // Dark translucent overlay with 260x260 cornerRadius 24 clear cutout
                ZStack {
                    Color.kilalaInk.opacity(0.62)

                    RoundedRectangle(cornerRadius: Self.scanBoxCornerRadius, style: .continuous)
                        .frame(width: Self.scanBoxSize, height: Self.scanBoxSize)
                        .blendMode(.destinationOut)
                }
                .compositingGroup()

                // Subtle 260x260 border frame aligned identically with cutout
                RoundedRectangle(cornerRadius: Self.scanBoxCornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    .frame(width: Self.scanBoxSize, height: Self.scanBoxSize)

                // Kilala Green + Sunrise corner scan brackets hugging the 260x260 cutout
                ScannerCornerBrackets(
                    bracketColor: isVerifying ? .kilalaSunrise : .kilalaGreen,
                    accentColor: .kilalaSunrise,
                    cornerRadius: Self.scanBoxCornerRadius
                )
                .frame(width: Self.scanBoxSize, height: Self.scanBoxSize)

                if isVerifying {
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .kilalaSunrise))
                            .scaleEffect(1.2)

                        Text("Verifying ID...")
                            .font(.kilala(.callout, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 18)
                    .background(Color.kilalaInk.opacity(0.84))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.kilalaSunrise.opacity(0.45), lineWidth: 1)
                    )
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // Layer 3: Safe-Area Top Header, Status Guidance & Bottom Controls
            VStack(spacing: 14) {
                topHeaderBar
                    .padding(.top, 4)

                // High-Contrast Brand Guidance Banner
                VStack(spacing: 6) {
                    KilalaBrandLogo(iconSize: 20, wordmarkSize: 17, reversed: true)

                    Text(statusBannerText)
                        .font(.kilala(.subheadline, weight: rawDetectionStatus != nil ? .bold : .semibold))
                        .foregroundColor(rawDetectionStatus != nil ? .kilalaSunrise : .white)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Color.kilalaInk.opacity(0.76))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            rawDetectionStatus != nil
                                ? Color.kilalaSunrise.opacity(0.65)
                                : Color.white.opacity(0.18),
                            lineWidth: 1
                        )
                )
                .padding(.horizontal, 20)

                Spacer()

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
                    .padding(.horizontal, 20)
                }

                VStack(spacing: 10) {
                    if !isEmbeddedInDrawer, let onLogout = onLogout {
                        Button(action: onLogout) {
                            Text("Log Out")
                                .font(.kilala(.footnote, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .frame(height: 36)
                                .background(Color.kilalaInk.opacity(0.65))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    Text("Trouble scanning? Tap Manual Input in the top-right corner.")
                        .font(.kilala(.caption, weight: .medium))
                        .foregroundColor(.white.opacity(0.84))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.bottom, 16)
            }
        }
        .background(Color.kilalaInk)
    }

    // MARK: - Verification

    private func verifyQRToken(_ qrToken: String) {
        let trimmedToken = qrToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty && !isVerifying && scanResult == nil else {
            isVerifying = false
            rawDetectionStatus = nil
            return
        }

        isVerifying = true
        rawDetectionStatus = "QR Detected — Verifying..."
        errorMessage = nil

        Task {
            do {
                let response = try await APIService.shared.verifyScan(qrToken: trimmedToken, token: token)
                await MainActor.run {
                    let feedback = UINotificationFeedbackGenerator()
                    feedback.notificationOccurred(response.isValid ? .success : .error)
                    isVerifying = false
                    rawDetectionStatus = nil
                    scanResult = response
                }
            } catch {
                await MainActor.run {
                    let feedback = UINotificationFeedbackGenerator()
                    feedback.notificationOccurred(.error)
                    isVerifying = false
                    rawDetectionStatus = nil
                    let detail = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                    errorMessage = detail.isEmpty
                        ? "Unable to verify QR code. Check your connection or business accreditation."
                        : "Verification failed: \(detail)"
                }
            }
        }
    }
}

// MARK: - Kilala Corner Scan Brackets

private struct ScannerCornerBrackets: View {
    var bracketColor: Color = .kilalaGreen
    var accentColor: Color = .kilalaSunrise
    var cornerRadius: CGFloat = 24

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let leg: CGFloat = 38
            let r = min(cornerRadius, leg)
            let inset: CGFloat = 0

            var brackets = Path()

            // Top-left
            brackets.move(to: CGPoint(x: inset, y: inset + leg))
            brackets.addLine(to: CGPoint(x: inset, y: inset + r))
            brackets.addQuadCurve(
                to: CGPoint(x: inset + r, y: inset),
                control: CGPoint(x: inset, y: inset)
            )
            brackets.addLine(to: CGPoint(x: inset + leg, y: inset))

            // Top-right
            brackets.move(to: CGPoint(x: w - inset - leg, y: inset))
            brackets.addLine(to: CGPoint(x: w - inset - r, y: inset))
            brackets.addQuadCurve(
                to: CGPoint(x: w - inset, y: inset + r),
                control: CGPoint(x: w - inset, y: inset)
            )
            brackets.addLine(to: CGPoint(x: w - inset, y: inset + leg))

            // Bottom-right
            brackets.move(to: CGPoint(x: w - inset, y: h - inset - leg))
            brackets.addLine(to: CGPoint(x: w - inset, y: h - inset - r))
            brackets.addQuadCurve(
                to: CGPoint(x: w - inset - r, y: h - inset),
                control: CGPoint(x: w - inset, y: h - inset)
            )
            brackets.addLine(to: CGPoint(x: w - inset - leg, y: h - inset))

            // Bottom-left
            brackets.move(to: CGPoint(x: inset + leg, y: h - inset))
            brackets.addLine(to: CGPoint(x: inset + r, y: h - inset))
            brackets.addQuadCurve(
                to: CGPoint(x: inset, y: h - inset - r),
                control: CGPoint(x: inset, y: h - inset)
            )
            brackets.addLine(to: CGPoint(x: inset, y: h - inset - leg))

            // Subtle outer highlight for high contrast over bright camera feeds
            context.stroke(
                brackets,
                with: .color(Color.white.opacity(0.26)),
                style: StrokeStyle(lineWidth: 6.5, lineCap: .round, lineJoin: .round)
            )

            // Primary Kilala Green (or Sunrise when verifying) brackets
            context.stroke(
                brackets,
                with: .color(bracketColor),
                style: StrokeStyle(lineWidth: 4.2, lineCap: .round, lineJoin: .round)
            )

            // Crisp Sunrise accent ticks inside top-left and bottom-right corners
            var accents = Path()
            let accentOffset: CGFloat = 9
            let accentLeg: CGFloat = 14
            let accentRadius: CGFloat = max(4, r - accentOffset)

            // Top-left inner tick
            accents.move(to: CGPoint(x: accentOffset, y: accentOffset + accentLeg))
            accents.addLine(to: CGPoint(x: accentOffset, y: accentOffset + accentRadius))
            accents.addQuadCurve(
                to: CGPoint(x: accentOffset + accentRadius, y: accentOffset),
                control: CGPoint(x: accentOffset, y: accentOffset)
            )
            accents.addLine(to: CGPoint(x: accentOffset + accentLeg, y: accentOffset))

            // Bottom-right inner tick
            accents.move(to: CGPoint(x: w - accentOffset, y: h - accentOffset - accentLeg))
            accents.addLine(to: CGPoint(x: w - accentOffset, y: h - accentOffset - accentRadius))
            accents.addQuadCurve(
                to: CGPoint(x: w - accentOffset - accentRadius, y: h - accentOffset),
                control: CGPoint(x: w - accentOffset, y: h - accentOffset)
            )
            accents.addLine(to: CGPoint(x: w - accentOffset - accentLeg, y: h - accentOffset))

            context.stroke(
                accents,
                with: .color(accentColor.opacity(0.95)),
                style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
            )
        }
    }
}

// MARK: - Manual QR Input Sheet (Kilala Paper + 16pt White Card)

private struct ManualQRInputSheet: View {
    @Binding var manualQRToken: String
    let isVerifying: Bool
    let onVerify: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFieldFocused: Bool

    private var trimmedToken: String {
        manualQRToken.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canVerify: Bool {
        !isVerifying && !trimmedToken.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.kilalaPaper
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 14) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("QR CODE TOKEN")
                                    .font(.kilala(.caption, weight: .bold))
                                    .tracking(0.8)
                                    .foregroundColor(.kilalaInkSecondary)

                                Text("Enter or paste the cardholder's Kilala QR token to verify their privilege status.")
                                    .font(.kilala(.footnote))
                                    .foregroundColor(.kilalaInkSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            HStack(spacing: 8) {
                                TextField(
                                    "Paste QR token (e.g. KILALA-QR-...)",
                                    text: $manualQRToken,
                                    prompt: Text(verbatim: "KILALA-QR-...").foregroundStyle(Color.kilalaInk.opacity(0.4))
                                )
                                .font(.kilalaMono(.callout, weight: .medium))
                                .foregroundColor(.kilalaInk)
                                .tint(.kilalaGreen)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .submitLabel(.go)
                                .focused($isFieldFocused)
                                .onSubmit {
                                    if canVerify {
                                        onVerify(trimmedToken)
                                    }
                                }

                                if !manualQRToken.isEmpty {
                                    Button {
                                        manualQRToken = ""
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 16))
                                            .foregroundColor(.kilalaInkMuted)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Clear QR code")
                                }
                            }
                            .padding(.horizontal, 12)
                            .frame(minHeight: 48)
                            .background(Color.kilalaPaper.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(
                                        isFieldFocused ? Color.kilalaGreen : Color.kilalaBorder,
                                        lineWidth: isFieldFocused ? 1.5 : 1
                                    )
                            )

                            Button {
                                isFieldFocused = false
                                onVerify(trimmedToken)
                            } label: {
                                HStack(spacing: 8) {
                                    if isVerifying {
                                        ProgressView()
                                            .tint(.white)
                                        Text("Verifying Code...")
                                    } else {
                                        Image(systemName: "checkmark.shield.fill")
                                            .font(.system(size: 16, weight: .semibold))
                                            .accessibilityHidden(true)
                                        Text("Verify Code")
                                    }
                                }
                                .font(.kilala(.callout, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(canVerify ? Color.kilalaGreen : Color.kilalaInkMuted)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .disabled(!canVerify)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.kilalaMintBorder, lineWidth: 1)
                        )
                    }
                    .padding(16)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Manual QR Input")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.kilalaPaper, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.kilala(.subheadline, weight: .semibold))
                    .foregroundColor(.kilalaInk)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    isFieldFocused = true
                }
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
        context.coordinator.requestAuthorizationAndStart()
        return previewView
    }

    func updateUIView(_ uiView: CameraPreviewView, context: Context) {
        // Only update scan gating and callbacks — never recreate or restart AVCaptureSession.
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
        private var configuredDevice: AVCaptureDevice?

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

        func requestAuthorizationAndStart() {
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                configureAndStartIfNeeded()
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    guard granted else { return }
                    Task { @MainActor [weak self] in
                        self?.configureAndStartIfNeeded()
                    }
                }
            default:
                break
            }
        }

        private func discoverBestBackCamera() -> AVCaptureDevice? {
            let preferredTypes: [AVCaptureDevice.DeviceType] = [
                .builtInTripleCamera,
                .builtInDualWideCamera,
                .builtInWideAngleCamera
            ]
            let discoverySession = AVCaptureDevice.DiscoverySession(
                deviceTypes: preferredTypes,
                mediaType: .video,
                position: .back
            )
            for deviceType in preferredTypes {
                if let match = discoverySession.devices.first(where: { $0.deviceType == deviceType }) {
                    return match
                }
            }
            return discoverySession.devices.first ?? AVCaptureDevice.default(for: .video)
        }

        private func configureAndStartIfNeeded() {
            guard !isSessionConfigured else {
                startRunningIfNeeded()
                return
            }

            guard let videoCaptureDevice = discoverBestBackCamera() else {
                return
            }

            guard let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice) else {
                return
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
            // Add output strictly BEFORE setting metadataObjectTypes, and attach retained Coordinator on .main queue.
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
            if metadataOutput.availableMetadataObjectTypes.contains(.qr) {
                metadataOutput.metadataObjectTypes = [.qr]
            }
            // Full-frame detection: leave metadataOutput.rectOfInterest at default (0, 0, 1, 1).

            captureSession.commitConfiguration()

            Self.applyOptimalCameraSettings(to: videoCaptureDevice, applyZoom: false)
            configuredDevice = videoCaptureDevice
            isSessionConfigured = true

            startRunningIfNeeded()
        }

        private nonisolated static func applyOptimalCameraSettings(
            to device: AVCaptureDevice,
            applyZoom: Bool
        ) {
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }

                if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                }
                if device.isAutoFocusRangeRestrictionSupported {
                    device.autoFocusRangeRestriction = .near
                }
                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                }
                if applyZoom {
                    let targetZoom = min(2.0, device.activeFormat.videoMaxZoomFactor)
                    if targetZoom >= 1.0 {
                        device.videoZoomFactor = targetZoom
                    }
                }
            } catch {
                // Keep default camera settings if device lock fails
            }
        }

        private func startRunningIfNeeded() {
            let session = captureSession
            let device = configuredDevice
            sessionQueue.async {
                if !session.isRunning {
                    session.startRunning()
                }
                if let device {
                    Self.applyOptimalCameraSettings(to: device, applyZoom: true)
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
