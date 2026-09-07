import SwiftUI

// MARK: - Scan Target

/// The bracket the user aims with. Wide and green for a barcode, shorter and rose
/// for the printed date; the recognized product name is pinned above it on step 2.
struct ScanTarget: View {
    let step: ScannerViewModel.Step
    let productName: String

    var body: some View {
        VStack(spacing: FTSpacing.lg) {
            if step == .date, !productName.isEmpty {
                DetectedLabel(icon: "barcode.viewfinder", text: productName, color: .ftPrimary)
            }

            ZStack {
                ScanBracket(
                    width: step == .barcode ? 280 : 250,
                    height: step == .barcode ? 150 : 92,
                    cornerSize: 16,
                    borderWidth: 4,
                    color: step == .barcode ? .ftPrimaryFixed.opacity(0.95) : .ftTertiaryContainer.opacity(0.95)
                )
                if step == .barcode {
                    ScanLineView()
                        .frame(width: 252)
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.ftTertiaryContainer.opacity(0.14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.ftTertiaryContainer.opacity(0.9), lineWidth: 1.5)
                        )
                        .frame(width: 206, height: 40)
                }
            }

            Text(step == .barcode ? "Point at the barcode" : "Now the best-before date")
                .font(FTFonts.bodyMedium(14))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.black.opacity(0.4))
                .clipShape(Capsule())
        }
    }
}

/// Small pill announcing something the camera recognized.
struct DetectedLabel: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(color)
            Text(text)
                .font(FTFonts.bodyMediumFont)
                .foregroundStyle(Color.ftOnSurface)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.ftSurfaceContainerLowest.opacity(0.92))
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }
}

// MARK: - Camera Notice

/// Explains why the live preview is empty and, when access was denied, offers a
/// shortcut to Settings. Only exists for the denied/unavailable states.
struct CameraNotice: View {
    let state: ScannerViewModel.CameraState

    init?(state: ScannerViewModel.CameraState) {
        guard state == .denied || state == .unavailable else { return nil }
        self.state = state
    }

    var body: some View {
        VStack(spacing: FTSpacing.md) {
            Image(systemName: state == .denied ? "camera.fill" : "camera.metering.unknown")
                .font(.system(size: 28))
                .foregroundStyle(Color.ftOnSurfaceVariant)
            Text(state == .denied ? "Camera access is off" : "No camera available")
                .font(FTFonts.headlineSmall)
                .foregroundStyle(Color.ftOnSurface)
            Text(state == .denied
                 ? "Allow camera access in Settings to scan, or skip to the date and enter it yourself."
                 : "This device has no usable camera. Skip to the date to type or estimate it.")
                .font(FTFonts.bodyMediumFont)
                .foregroundStyle(Color.ftOnSurfaceVariant)
                .multilineTextAlignment(.center)
            if state == .denied {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(FTPrimaryButtonStyle())
                .padding(.top, FTSpacing.xs)
            }
        }
        .padding(FTSpacing.xl)
        .background(Color.ftSurfaceContainerLowest)
        .clipShape(RoundedRectangle(cornerRadius: FTRadius.xl, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 20, y: 8)
        .padding(.horizontal, FTSpacing.xl)
        .offset(y: 120)
        .accessibilityIdentifier("scanner.cameraNotice")
    }
}

// MARK: - Step 1 footer

/// Escape hatches under the barcode bracket for items without a barcode.
struct BarcodeStepFooter: View {
    let onSkip: () -> Void
    let onAddManual: () -> Void

    var body: some View {
        VStack(spacing: FTSpacing.md) {
            Text("Loose produce or no barcode?")
                .font(FTFonts.bodyRegular(13))
                .foregroundStyle(.white.opacity(0.75))
            HStack(spacing: FTSpacing.md) {
                TranslucentButton(title: "Skip to the date", systemImage: "calendar", action: onSkip)
                TranslucentButton(title: "Add manually", systemImage: "keyboard", action: onAddManual)
            }
        }
        .padding(.horizontal, FTSpacing.xl)
        .padding(.bottom, 56)
    }
}

/// White-on-glass secondary button for use over the camera feed.
struct TranslucentButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 14))
                Text(title)
                    .font(FTFonts.bodySemiBold(14))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(.white.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: FTRadius.lg, style: .continuous))
        }
        .accessibilityLabel(title)
    }
}

/// Tonal secondary button used inside the white sheets.
struct TonalButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 14))
                Text(title)
                    .font(FTFonts.bodySemiBold(14))
            }
            .foregroundStyle(Color.ftPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.ftSurfaceContainerLow)
            .clipShape(RoundedRectangle(cornerRadius: FTRadius.lg, style: .continuous))
        }
        .accessibilityLabel(title)
    }
}

// MARK: - Slide-up sheet container

/// The scanner's slide-up card: 32pt top radius, drag handle, ambient shadow.
struct ScannerSheet<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.ftSurfaceVariant)
                .frame(width: 48, height: 4)
                .padding(.top, FTSpacing.lg)
                .padding(.bottom, FTSpacing.xl)
            VStack(spacing: FTSpacing.xl) {
                content
            }
            .padding(.horizontal, FTSpacing.xl)
            .padding(.bottom, FTSpacing.xxxl)
        }
        .frame(maxWidth: .infinity)
        .background(Color.ftSurfaceContainerLowest)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: FTRadius.section,
                topTrailingRadius: FTRadius.section
            )
        )
        .shadow(color: .black.opacity(0.1), radius: 20, y: -10)
        .ignoresSafeArea(.container, edges: .bottom)
    }
}

// MARK: - Step 2 sheet

/// Captures the expiry date: confirms a date read from the label, or falls back
/// to typing one or using a category shelf-life estimate.
struct DateStepSheet: View {
    @ObservedObject var viewModel: ScannerViewModel

    var body: some View {
        ScannerSheet {
            if let date = viewModel.recognizedDate {
                recognized(date)
            } else {
                switch viewModel.dateEntryMode {
                case .scanning: scanning
                case .typing: typing
                case .estimating: estimating
                }
            }
        }
    }

    private func recognized(_ date: Date) -> some View {
        Group {
            HStack(spacing: FTSpacing.lg) {
                iconBox("text.viewfinder", color: .ftTertiary)
                VStack(alignment: .leading, spacing: 4) {
                    Text(date.formatted(.dateTime.day().month(.abbreviated).year()))
                        .font(FTFonts.headlineSmall)
                        .foregroundStyle(Color.ftOnSurface)
                    Text("Read from the label · \(viewModel.daysFromToday(to: date)) days from today")
                        .font(FTFonts.bodyMediumFont)
                        .foregroundStyle(Color.ftOnSurfaceVariant)
                }
                Spacer(minLength: 0)
            }
            Button { viewModel.useRecognizedDate() } label: {
                Label("Use this date", systemImage: "checkmark")
            }
            .buttonStyle(FTPrimaryButtonStyle())
            HStack(spacing: FTSpacing.md) {
                TonalButton(title: "Type it instead", systemImage: "keyboard") {
                    viewModel.rescanDate()
                    viewModel.startTypingDate()
                }
                TonalButton(title: "Not this date", systemImage: "arrow.counterclockwise") {
                    viewModel.rescanDate()
                }
            }
        }
    }

    private var scanning: some View {
        Group {
            HStack(spacing: FTSpacing.lg) {
                iconBox(viewModel.isCameraLive ? "text.viewfinder" : "camera.metering.unknown", color: .ftTertiary)
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.isCameraLive ? "Looking for a printed date" : "No camera for the date")
                        .font(FTFonts.headlineSmall)
                        .foregroundStyle(Color.ftOnSurface)
                    Text(viewModel.isCameraLive
                         ? "Hold the best-before stamp inside the frame."
                         : "Type the date or use a shelf-life estimate.")
                        .font(FTFonts.bodyMediumFont)
                        .foregroundStyle(Color.ftOnSurfaceVariant)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: FTSpacing.md) {
                TonalButton(title: "Type it instead", systemImage: "keyboard") { viewModel.startTypingDate() }
                TonalButton(title: "No date printed", systemImage: "calendar.badge.exclamationmark") { viewModel.startEstimating() }
            }
        }
    }

    private var typing: some View {
        Group {
            VStack(alignment: .leading, spacing: 6) {
                Text("Type the date")
                    .font(FTFonts.headlineMedium)
                    .foregroundStyle(Color.ftOnSurface)
                Text(viewModel.draft.name.isEmpty ? "No barcode scanned" : viewModel.draft.name)
                    .font(FTFonts.bodyMediumFont)
                    .foregroundStyle(Color.ftOnSurfaceVariant)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            DatePicker("Expires on", selection: $viewModel.typedDate, displayedComponents: .date)
                .datePickerStyle(.compact)
                .tint(Color.ftPrimary)
                .font(FTFonts.bodyLarge)
                .padding(FTSpacing.lg)
                .background(Color.ftSurfaceContainerLow)
                .clipShape(RoundedRectangle(cornerRadius: FTRadius.lg, style: .continuous))
            Button { viewModel.useTypedDate() } label: {
                Label("Use this date", systemImage: "checkmark")
            }
            .buttonStyle(FTPrimaryButtonStyle())
            TonalButton(title: "No date printed", systemImage: "calendar.badge.exclamationmark") { viewModel.startEstimating() }
        }
    }

    private var estimating: some View {
        Group {
            VStack(alignment: .leading, spacing: 6) {
                Text("When does it expire?")
                    .font(FTFonts.headlineMedium)
                    .foregroundStyle(Color.ftOnSurface)
                Text(viewModel.draft.name.isEmpty ? "No date printed on the package" : "\(viewModel.draft.name) · no date printed")
                    .font(FTFonts.bodyMediumFont)
                    .foregroundStyle(Color.ftOnSurfaceVariant)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: FTSpacing.sm) {
                fieldLabel("CATEGORY")
                Picker("Category", selection: $viewModel.draft.category) {
                    ForEach(FoodCategory.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.menu)
                .tint(Color.ftPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: FTSpacing.sm) {
                fieldLabel("ESTIMATED EXPIRY")
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.ftTertiary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(viewModel.estimatedExpiry.formatted(.dateTime.day().month(.abbreviated))) · in \(viewModel.daysFromToday(to: viewModel.estimatedExpiry)) days")
                            .font(FTFonts.headlineSemiBold(16))
                            .foregroundStyle(Color.ftOnSurface)
                        Text("Typical shelf life for \(ShelfLifeEstimator.subject(for: viewModel.draft.category))")
                            .font(FTFonts.bodyRegular(13))
                            .foregroundStyle(Color.ftOnSurfaceVariant)
                    }
                    Spacer(minLength: 0)
                }
                .padding(FTSpacing.lg)
                .background(Color.ftSurfaceContainerLow)
                .clipShape(RoundedRectangle(cornerRadius: FTRadius.lg, style: .continuous))
                Text("The item is tagged as estimated, so you know the alert is a best guess.")
                    .font(FTFonts.bodyRegular(13))
                    .foregroundStyle(Color.ftOnSurfaceVariant)
            }

            Button { viewModel.useEstimate() } label: {
                Label("Use estimate", systemImage: "checkmark")
            }
            .buttonStyle(FTPrimaryButtonStyle())
            TonalButton(title: "Type the date instead", systemImage: "keyboard") { viewModel.startTypingDate() }
        }
    }

    private func iconBox(_ systemImage: String, color: Color) -> some View {
        RoundedRectangle(cornerRadius: FTRadius.lg)
            .fill(Color.ftSurfaceContainerLow)
            .frame(width: 56, height: 56)
            .overlay(
                Image(systemName: systemImage)
                    .font(.system(size: 24))
                    .foregroundStyle(color)
            )
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .tracking(1.5)
            .foregroundStyle(Color.ftOnSurfaceVariant)
    }
}

// MARK: - Step 3 confirm card

/// Review and adjust everything before the item is saved.
struct ConfirmCard: View {
    @ObservedObject var viewModel: ScannerViewModel
    let onConfirm: () -> Void
    @FocusState private var isNameFocused: Bool

    private var expirationBinding: Binding<Date> {
        Binding(
            get: { viewModel.draft.expirationDate ?? Date() },
            set: {
                viewModel.draft.expirationDate = $0
                viewModel.draft.isEstimatedExpiry = false
            }
        )
    }

    var body: some View {
        ScannerSheet {
            HStack(spacing: FTSpacing.lg) {
                RoundedRectangle(cornerRadius: FTRadius.lg)
                    .fill(Color.ftSurfaceContainerLow)
                    .frame(width: 64, height: 64)
                    .overlay(
                        Image(systemName: viewModel.draft.category.icon)
                            .font(.system(size: 24))
                            .foregroundStyle(Color.ftOnSurfaceVariant)
                    )
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Product name", text: $viewModel.draft.name)
                        .font(FTFonts.headlineMedium)
                        .foregroundStyle(Color.ftOnSurface)
                        .focused($isNameFocused)
                        .submitLabel(.done)
                        .onSubmit { isNameFocused = false }
                        .accessibilityIdentifier("scanner.nameField")
                    Text(subtitle)
                        .font(FTFonts.bodyMediumFont)
                        .foregroundStyle(Color.ftOnSurfaceVariant)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: FTSpacing.lg) {
                detailBox(label: "EXPIRATION") {
                    HStack(spacing: 6) {
                        Image(systemName: viewModel.draft.isEstimatedExpiry ? "sparkles" : "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(viewModel.draft.isEstimatedExpiry ? Color.ftTertiary : Color.ftPrimary)
                        DatePicker("", selection: expirationBinding, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .tint(Color.ftPrimary)
                    }
                }
                detailBox(label: "PLACEMENT") {
                    Picker("Placement", selection: $viewModel.draft.placement) {
                        ForEach(StoragePlacement.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .tint(Color.ftPrimary)
                }
            }

            if viewModel.draft.isEstimatedExpiry {
                infoChip(
                    icon: "sparkles",
                    text: "Estimated from typical shelf life for \(ShelfLifeEstimator.subject(for: viewModel.draft.category)).",
                    background: .ftTertiaryContainer.opacity(0.25),
                    foreground: .ftOnTertiaryContainer
                )
            }
            if let alertDate = viewModel.alertDate {
                infoChip(
                    icon: "calendar",
                    text: "Alert on \(alertDate.formatted(.dateTime.day().month(.abbreviated))), two days before it expires.",
                    background: .ftSecondaryContainer,
                    foreground: .ftOnSecondaryContainer
                )
            }

            Button(action: onConfirm) {
                Label("Add to Calendar & Set 2-Day Alert", systemImage: "calendar.badge.plus")
            }
            .buttonStyle(FTPrimaryButtonStyle())
            .disabled(!viewModel.canConfirm)
            .opacity(viewModel.canConfirm ? 1 : 0.5)
            .accessibilityIdentifier("scanner.confirm")
        }
    }

    private var subtitle: String {
        let parts = [viewModel.draft.brand, viewModel.draft.barcode ?? ""].filter { !$0.isEmpty }
        return parts.isEmpty ? "No barcode" : parts.joined(separator: " · ")
    }

    private func detailBox<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(Color.ftOnSurfaceVariant)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FTSpacing.lg)
        .background(Color.ftSurfaceContainerLow)
        .clipShape(RoundedRectangle(cornerRadius: FTRadius.lg, style: .continuous))
    }

    private func infoChip(icon: String, text: String, background: Color, foreground: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
            Text(text)
                .font(FTFonts.bodyRegular(13))
        }
        .foregroundStyle(foreground)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: FTRadius.lg, style: .continuous))
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
                    colors: [.ftPrimaryFixed.opacity(0), .ftPrimaryFixed, .ftPrimaryFixed.opacity(0)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 2)
            .shadow(color: .ftPrimaryFixed.opacity(0.6), radius: 4, y: 0)
            .offset(y: offset)
            .onAppear {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    offset = 60
                }
            }
    }
}
