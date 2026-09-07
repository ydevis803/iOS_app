import SwiftUI
import AVFoundation
import UIKit

// MARK: - Scanner View (Barcode via AVFoundation)

/// Full-screen camera scanner that detects product barcodes and presents a
/// confirmation card before adding the item via ``onItemScanned``.
struct ScannerView: View {
    @StateObject private var viewModel = ScannerViewModel()
    @Environment(\.dismiss) private var dismiss

    var onItemScanned: ((ScanResult) -> Void)?

    var body: some View {
        ZStack {
            // Camera layer
            CameraPreviewLayer(session: viewModel.captureSession)
                .ignoresSafeArea()

            // Overlay controls
            VStack {
                topControls
                Spacer()
                scanningBrackets
                Spacer()
            }
            .padding(.top, 60)
            .padding(.bottom, 120)

            // Camera unavailable / permission denied notice
            if let notice = cameraNotice(for: viewModel.cameraState) {
                notice
                    .transition(.opacity)
            }

            // Slide-up confirmation card
            if viewModel.showConfirmation, let result = viewModel.scanResult {
                confirmationCard(result: result)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear { viewModel.startScanning() }
        .onDisappear { viewModel.stopScanning() }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: viewModel.showConfirmation)
    }

    // MARK: - Top Controls

    private var topControls: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(.black.opacity(0.4))
                    .clipShape(Circle())
                    .background(.ultraThinMaterial.opacity(0.3), in: Circle())
            }
            .accessibilityIdentifier("scanner.close")

            Spacer()

            // Auto-Scanning indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.ftPrimaryFixed)
                    .frame(width: 8, height: 8)
                    .modifier(PulseModifier())
                Text("Auto-Scanning")
                    .font(FTFonts.bodyMediumFont)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.black.opacity(0.4))
            .background(.ultraThinMaterial.opacity(0.3))
            .clipShape(Capsule())

            Spacer()

            Button {
                viewModel.toggleFlash()
            } label: {
                Image(systemName: viewModel.isFlashOn ? "bolt.fill" : "bolt.slash")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(.black.opacity(0.4))
                    .clipShape(Circle())
                    .background(.ultraThinMaterial.opacity(0.3), in: Circle())
            }
        }
        .padding(.horizontal, FTSpacing.xl)
    }

    // MARK: - Scanning Brackets

    private var scanningBrackets: some View {
        VStack(spacing: 32) {
            // Barcode bracket
            ZStack {
                if let productName = viewModel.scanResult?.productName {
                    detectedLabel(icon: "barcode.viewfinder", text: "Product: \(productName)", color: .ftPrimary)
                        .offset(y: -50)
                }
                ScanBracket(width: 256, height: 128, cornerSize: 16, borderWidth: 4, color: .ftPrimary.opacity(0.7))
                    .overlay(
                        ScanLineView()
                    )
            }

            // Expiry bracket
            ZStack {
                if let date = viewModel.scanResult?.expirationDate {
                    let formatted = date.formatted(.dateTime.day().month(.abbreviated).year())
                    detectedLabel(icon: "calendar", text: "Expiry: \(formatted)", color: .ftTertiary)
                        .offset(y: -40)
                }
                ScanBracket(width: 192, height: 64, cornerSize: 12, borderWidth: 2, color: .ftTertiaryContainer.opacity(0.7))
            }
        }
    }

    // MARK: - Camera Notice

    /// Explains why the live preview is empty and, when access was denied, offers a
    /// shortcut to Settings. Returns `nil` while the camera is usable.
    private func cameraNotice(for state: ScannerViewModel.CameraState) -> AnyView? {
        switch state {
        case .idle, .running:
            return nil
        case .denied:
            return AnyView(
                noticeCard(
                    icon: "camera.fill",
                    title: "Camera access is off",
                    message: "Allow camera access in Settings to scan barcodes, or add items manually from the Pantry.",
                    buttonTitle: "Open Settings"
                ) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            )
        case .unavailable:
            return AnyView(
                noticeCard(
                    icon: "camera.metering.unknown",
                    title: "No camera available",
                    message: "This device has no usable camera. You can still add items manually from the Pantry.",
                    buttonTitle: nil,
                    action: nil
                )
            )
        }
    }

    private func noticeCard(
        icon: String,
        title: String,
        message: String,
        buttonTitle: String?,
        action: (() -> Void)?
    ) -> some View {
        VStack {
            Spacer()
            VStack(spacing: FTSpacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundStyle(Color.ftOnSurfaceVariant)
                Text(title)
                    .font(FTFonts.headlineSmall)
                    .foregroundStyle(Color.ftOnSurface)
                Text(message)
                    .font(FTFonts.bodyMediumFont)
                    .foregroundStyle(Color.ftOnSurfaceVariant)
                    .multilineTextAlignment(.center)
                if let buttonTitle, let action {
                    Button(buttonTitle, action: action)
                        .buttonStyle(FTPrimaryButtonStyle())
                        .padding(.top, FTSpacing.xs)
                }
            }
            .padding(FTSpacing.xl)
            .background(Color.ftSurfaceContainerLowest)
            .clipShape(RoundedRectangle(cornerRadius: FTRadius.xl, style: .continuous))
            .shadow(color: .black.opacity(0.1), radius: 20, y: 8)
            .padding(.horizontal, FTSpacing.xl)
            .padding(.bottom, 140)
        }
        .accessibilityIdentifier("scanner.cameraNotice")
    }

    private func detectedLabel(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(color)
            Text(text)
                .font(FTFonts.bodyMediumFont)
                .foregroundStyle(Color.ftOnSurface)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.ftSurfaceContainerLowest.opacity(0.9))
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }

    // MARK: - Confirmation Card

    private func confirmationCard(result: ScanResult) -> some View {
        VStack {
            Spacer()
            VStack(spacing: 0) {
                // Drag handle
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.ftSurfaceVariant)
                    .frame(width: 48, height: 4)
                    .padding(.top, FTSpacing.lg)
                    .padding(.bottom, FTSpacing.xl)

                VStack(spacing: FTSpacing.xl) {
                    // Header
                    HStack(spacing: FTSpacing.lg) {
                        RoundedRectangle(cornerRadius: FTRadius.lg)
                            .fill(Color.ftSurfaceContainerLow)
                            .frame(width: 64, height: 64)
                            .overlay(
                                Image(systemName: "shippingbox")
                                    .font(.system(size: 24))
                                    .foregroundStyle(Color.ftOnSurfaceVariant)
                            )
                        VStack(alignment: .leading, spacing: 4) {
                            Text(result.productName ?? "Unknown Product")
                                .font(FTFonts.headlineMedium)
                                .foregroundStyle(Color.ftOnSurface)
                            Text(result.barcode ?? "Scanned item")
                                .font(FTFonts.bodyMediumFont)
                                .foregroundStyle(Color.ftOnSurfaceVariant)
                        }
                        Spacer()
                    }

                    // Details grid
                    HStack(spacing: FTSpacing.lg) {
                        detailBox(
                            label: "EXPIRATION",
                            value: result.expirationDate?.formatted(.dateTime.day().month(.abbreviated).year()) ?? "Not detected",
                            icon: "checkmark.circle.fill",
                            iconColor: .ftPrimary
                        )
                        detailBox(
                            label: "PLACEMENT",
                            value: "Fridge Door",
                            icon: "refrigerator",
                            iconColor: .ftSecondary
                        )
                    }

                    // CTA
                    Button {
                        onItemScanned?(result)
                        viewModel.confirmAndReset()
                        dismiss()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "calendar.badge.plus")
                                .font(.system(size: 16))
                            Text("Add to Calendar & Set 2-Day Alert")
                        }
                    }
                    .buttonStyle(FTPrimaryButtonStyle())
                    .padding(.top, FTSpacing.sm)
                }
                .padding(.horizontal, FTSpacing.xl)
                .padding(.bottom, FTSpacing.xxxl)
            }
            .background(Color.ftSurfaceContainerLowest)
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: FTRadius.section,
                    topTrailingRadius: FTRadius.section
                )
            )
            .shadow(color: .black.opacity(0.1), radius: 20, y: -10)
        }
        .ignoresSafeArea(.container, edges: .bottom)
    }

    private func detailBox(label: String, value: String, icon: String, iconColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(Color.ftOnSurfaceVariant)

            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(iconColor)
                Text(value)
                    .font(FTFonts.headlineSemiBold(14))
                    .foregroundStyle(Color.ftOnSurface)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FTSpacing.lg)
        .background(Color.ftSurfaceContainerLow)
        .clipShape(RoundedRectangle(cornerRadius: FTRadius.lg, style: .continuous))
    }
}

// MARK: - Scanner ViewModel

/// Drives the capture session: configures the camera, surfaces detected barcodes as a
/// ``ScanResult``, and manages flash and confirmation state.
@MainActor
final class ScannerViewModel: ObservableObject {
    /// Whether the live camera can be used, and if not, why.
    enum CameraState: Equatable {
        case idle
        case running
        /// The user denied access (or it is restricted); the app cannot prompt again.
        case denied
        /// No usable camera on this device (e.g. the simulator).
        case unavailable
    }

    @Published var scanResult: ScanResult?
    @Published var showConfirmation = false
    @Published var isFlashOn = false
    @Published private(set) var cameraState: CameraState = .idle

    let captureSession = AVCaptureSession()
    private var metadataOutput: AVCaptureMetadataOutput?
    private let scanDelegate = ScannerDelegate()
    private let authorizationStatus: () -> AVAuthorizationStatus
    private let requestAccess: () async -> Bool

    /// The permission hooks default to `AVCaptureDevice` and are injectable so the
    /// authorization flow can be unit-tested without a real camera.
    init(
        authorizationStatus: @escaping () -> AVAuthorizationStatus = {
            AVCaptureDevice.authorizationStatus(for: .video)
        },
        requestAccess: @escaping () async -> Bool = {
            await AVCaptureDevice.requestAccess(for: .video)
        }
    ) {
        self.authorizationStatus = authorizationStatus
        self.requestAccess = requestAccess
        scanDelegate.onBarcodeDetected = { [weak self] barcode in
            Task { @MainActor in
                guard let self, self.scanResult?.barcode == nil else { return }
                self.scanResult = ScanResult(
                    productName: self.productNameFromBarcode(barcode),
                    expirationDate: nil,
                    barcode: barcode
                )
                // Reveal the confirmation card once a barcode is captured.
                self.showConfirmation = true
            }
        }
    }

    /// Starts the camera if permitted, prompts when permission has not been decided
    /// yet, and otherwise records why scanning is not possible in ``cameraState``.
    func startScanning() {
        switch authorizationStatus() {
        case .authorized:
            setupCaptureSession()
        case .notDetermined:
            Task { [weak self] in
                guard let self else { return }
                await self.requestCameraAccess()
            }
        case .denied, .restricted:
            cameraState = .denied
        @unknown default:
            cameraState = .denied
        }
    }

    func stopScanning() {
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }

    func toggleFlash() {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            isFlashOn.toggle()
            device.torchMode = isFlashOn ? .on : .off
            device.unlockForConfiguration()
        } catch {}
    }

    func confirmAndReset() {
        showConfirmation = false
        scanResult = nil
    }

    // MARK: - Private

    private func requestCameraAccess() async {
        if await requestAccess() {
            setupCaptureSession()
        } else {
            cameraState = .denied
        }
    }

    private func setupCaptureSession() {
        guard captureSession.isRunning == false else {
            cameraState = .running
            return
        }
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            cameraState = .unavailable
            return
        }

        captureSession.beginConfiguration()

        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        }

        let metaOutput = AVCaptureMetadataOutput()
        if captureSession.canAddOutput(metaOutput) {
            captureSession.addOutput(metaOutput)
            metaOutput.setMetadataObjectsDelegate(scanDelegate, queue: .main)
            metaOutput.metadataObjectTypes = [
                .ean8, .ean13, .upce, .code128, .code39, .code93,
                .interleaved2of5, .itf14, .dataMatrix, .qr
            ]
            self.metadataOutput = metaOutput
        }

        captureSession.commitConfiguration()
        cameraState = .running

        Task.detached { [captureSession] in
            captureSession.startRunning()
        }
    }

    private func productNameFromBarcode(_ barcode: String) -> String {
        // In production, query an API like Open Food Facts.
        // For demo, return a placeholder based on barcode prefix.
        let knownProducts: [String: String] = [
            "049000": "Coca-Cola",
            "041570": "Almond Milk",
            "021130": "Dannon Yogurt"
        ]
        let prefix = String(barcode.prefix(6))
        return knownProducts[prefix] ?? "Scanned Product"
    }
}

// MARK: - AVCaptureMetadataOutput Delegate

/// Bridges `AVCaptureMetadataOutput` callbacks into a simple barcode-string closure.
final class ScannerDelegate: NSObject, AVCaptureMetadataOutputObjectsDelegate {
    var onBarcodeDetected: ((String) -> Void)?

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let stringValue = object.stringValue else { return }
        onBarcodeDetected?(stringValue)
    }
}

// MARK: - Camera Preview UIViewRepresentable

/// Hosts an `AVCaptureVideoPreviewLayer` so the live camera feed can be shown in SwiftUI.
struct CameraPreviewLayer: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        context.coordinator.previewLayer = previewLayer
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.previewLayer?.frame = uiView.bounds
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}

// MARK: - Scan Bracket Shape

/// Decorative framing brackets drawn around a scan target area.
struct ScanBracket: View {
    let width: CGFloat
    let height: CGFloat
    let cornerSize: CGFloat
    let borderWidth: CGFloat
    let color: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerSize / 2)
                .stroke(color.opacity(0.3), lineWidth: 1)
                .frame(width: width, height: height)

            // Corner brackets
            ForEach(0..<4, id: \.self) { index in
                CornerBracket(size: cornerSize, lineWidth: borderWidth, color: color)
                    .rotationEffect(.degrees(Double(index) * 90))
                    .offset(
                        x: (index == 0 || index == 3) ? -width / 2 + cornerSize / 2 : width / 2 - cornerSize / 2,
                        y: (index == 0 || index == 1) ? -height / 2 + cornerSize / 2 : height / 2 - cornerSize / 2
                    )
            }
        }
        .frame(width: width, height: height)
    }
}

/// A single rounded L-shaped corner used to build ``ScanBracket``.
struct CornerBracket: View {
    let size: CGFloat
    let lineWidth: CGFloat
    let color: Color

    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: size))
            path.addLine(to: CGPoint(x: 0, y: lineWidth))
            path.addQuadCurve(to: CGPoint(x: lineWidth, y: 0), control: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: size, y: 0))
        }
        .stroke(color, lineWidth: lineWidth)
        .frame(width: size, height: size)
    }
}

// MARK: - Scan Line Animation

/// Animated horizontal line that sweeps up and down to suggest active scanning.
struct ScanLineView: View {
    @State private var offset: CGFloat = -60

    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.ftPrimary.opacity(0), .ftPrimary, .ftPrimary.opacity(0)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 2)
            .shadow(color: .ftPrimary.opacity(0.5), radius: 4, y: 0)
            .offset(y: offset)
            .onAppear {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    offset = 60
                }
            }
    }
}

// MARK: - Pulse Animation Modifier

/// Applies a repeating scale/opacity pulse to its content (used for the live indicator dot).
struct PulseModifier: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.3 : 1.0)
            .opacity(isPulsing ? 0.6 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
}
