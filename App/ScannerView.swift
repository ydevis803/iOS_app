import SwiftUI

// MARK: - Scanner View (two-step: barcode → expiry date → confirm)

/// Full-screen camera scanner. Step 1 reads the product barcode, step 2 reads the
/// printed best-before date (with typed and estimated fallbacks), and step 3 lets
/// the user confirm and adjust before the item is added via ``onItemScanned``.
struct ScannerView: View {
    @StateObject private var viewModel = ScannerViewModel()
    @Environment(\.dismiss) private var dismiss

    var onItemScanned: ((ScanResult) -> Void)?
    /// Called when the user chooses manual entry instead of scanning.
    var onAddManual: (() -> Void)?

    var body: some View {
        ZStack {
            cameraLayer
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topControls
                Spacer()
                if viewModel.step != .confirm {
                    ScanTarget(step: viewModel.step, productName: viewModel.draft.name)
                        .transition(.opacity)
                }
                Spacer()
            }
            .padding(.top, 60)
            .padding(.bottom, viewModel.step == .photo ? 220 : 320)

            if viewModel.step == .photo, let notice = CameraNotice(state: viewModel.cameraState) {
                notice.transition(.opacity)
            }

            VStack {
                Spacer()
                switch viewModel.step {
                case .photo:
                    PhotoStepFooter(
                        isCapturing: viewModel.isCapturing,
                        onCapture: { viewModel.capturePhoto() },
                        onSkip: { viewModel.skipPhoto() },
                        onAddManual: addManually
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                case .date:
                    DateStepSheet(viewModel: viewModel)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                case .confirm:
                    ConfirmCard(viewModel: viewModel, onConfirm: confirm)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .onAppear { viewModel.startScanning() }
        .onDisappear { viewModel.stopScanning() }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: viewModel.step)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: viewModel.dateEntryMode)
        .animation(.easeInOut(duration: 0.25), value: viewModel.recognizedDate)
    }

    // MARK: - Camera

    private var cameraLayer: some View {
        ZStack {
            Color.black
            if viewModel.isCameraLive {
                DataScannerView(
                    isActive: viewModel.step != .confirm,
                    camera: viewModel.camera,
                    onText: { viewModel.handleRecognizedText($0) }
                )
            }
        }
    }

    // MARK: - Top Controls

    private var topControls: some View {
        HStack {
            if viewModel.step == .photo {
                circleButton(systemImage: "xmark", identifier: "scanner.close") { dismiss() }
            } else {
                circleButton(systemImage: "chevron.left", identifier: "scanner.back") { viewModel.goBack() }
            }

            Spacer()
            ScannerStepsPill(step: viewModel.step)
            Spacer()

            circleButton(systemImage: viewModel.isFlashOn ? "bolt.fill" : "bolt.slash", identifier: "scanner.flash") {
                viewModel.toggleFlash()
            }
        }
        .padding(.horizontal, FTSpacing.xl)
    }

    private func circleButton(systemImage: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(.black.opacity(0.4))
                .clipShape(Circle())
                .background(.ultraThinMaterial.opacity(0.3), in: Circle())
        }
        .accessibilityIdentifier(identifier)
    }

    // MARK: - Actions

    private func addManually() {
        dismiss()
        onAddManual?()
    }

    private func confirm() {
        onItemScanned?(viewModel.makeResult())
        viewModel.reset()
        dismiss()
    }
}

// MARK: - Steps Pill

/// "1 Barcode · 2 Date" progress pill: the active step carries a live dot, a
/// finished one a check.
struct ScannerStepsPill: View {
    let step: ScannerViewModel.Step

    var body: some View {
        HStack(spacing: 12) {
            segment(number: 1, title: "Photo", isActive: step == .photo, isDone: step != .photo)
            Rectangle()
                .fill(.white.opacity(0.3))
                .frame(width: 1, height: 14)
            segment(number: 2, title: "Date", isActive: step == .date, isDone: step == .confirm)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.black.opacity(0.4))
        .background(.ultraThinMaterial.opacity(0.3))
        .clipShape(Capsule())
    }

    private func segment(number: Int, title: String, isActive: Bool, isDone: Bool) -> some View {
        HStack(spacing: 6) {
            if isDone {
                Circle()
                    .fill(Color.ftPrimaryFixed)
                    .frame(width: 16, height: 16)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.ftOnPrimaryContainer)
                    )
            } else if isActive {
                Circle()
                    .fill(Color.ftPrimaryFixed)
                    .frame(width: 8, height: 8)
                    .modifier(PulseModifier())
                    .padding(.horizontal, 4)
            } else {
                Circle()
                    .stroke(.white.opacity(0.45), lineWidth: 1.5)
                    .frame(width: 16, height: 16)
                    .overlay(
                        Text("\(number)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    )
            }
            Text(title)
                .font(FTFonts.bodyMedium(14))
                .foregroundStyle(isActive || isDone ? .white : .white.opacity(0.55))
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
