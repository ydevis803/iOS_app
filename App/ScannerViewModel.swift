import AVFoundation
import SwiftUI
import UIKit
import VisionKit

/// Drives the two-step scanner: read the barcode, then the printed expiry date,
/// then confirm. Camera permission and scanner availability are injectable so the
/// whole flow can be unit-tested without a camera.
@MainActor
final class ScannerViewModel: ObservableObject {
    /// Whether the live camera can be used, and if not, why.
    enum CameraState: Equatable {
        case idle
        case running
        /// The user denied access (or it is restricted); the app cannot prompt again.
        case denied
        /// No usable camera or scanner on this device (e.g. the simulator).
        case unavailable
    }

    /// The scanner's three screens, in order.
    enum Step: Equatable {
        case photo
        case date
        case confirm
    }

    /// How the expiry date is being captured on the date step.
    enum DateEntryMode: Equatable {
        case scanning
        case typing
        case estimating
    }

    /// The item being built up across the steps.
    struct Draft: Equatable {
        var name = ""
        var brand = ""
        var barcode: String?
        var expirationDate: Date?
        var isEstimatedExpiry = false
        var placement: StoragePlacement = .fridge
        var category: FoodCategory = .other
    }

    @Published private(set) var step: Step = .photo
    @Published var draft = Draft()
    @Published var dateEntryMode: DateEntryMode = .scanning
    /// A date read from the label, shown for confirmation before it is used.
    @Published private(set) var recognizedDate: Date?
    @Published var typedDate: Date
    @Published private(set) var cameraState: CameraState = .idle
    @Published var isFlashOn = false
    /// `true` while a still is being captured and recognized.
    @Published private(set) var isCapturing = false
    /// A short caption describing how the name was obtained (label vs. photo).
    @Published private(set) var recognitionNote: String?

    /// Bridge to the VisionKit controller's still-photo capture.
    let camera = ScannerCamera()

    private let authorizationStatus: () -> AVAuthorizationStatus
    private let requestAccess: () async -> Bool
    private let isScannerAvailable: @MainActor () -> Bool
    private let parser: ExpiryDateParser
    private let now: () -> Date
    private let recognizeItem: (UIImage) async -> ItemRecognition?

    /// - Parameters:
    ///   - authorizationStatus: Camera permission lookup (defaults to `AVCaptureDevice`).
    ///   - requestAccess: Camera permission prompt (defaults to `AVCaptureDevice`).
    ///   - isScannerAvailable: Whether VisionKit's data scanner can run on this device.
    ///   - parser: Expiry-date parser applied to recognized label text.
    ///   - now: Clock, injectable for deterministic tests.
    ///   - recognizeItem: Names an item from a captured photo (label OCR, then
    ///     produce classification); injectable so the capture flow can be tested.
    init(
        authorizationStatus: @escaping () -> AVAuthorizationStatus = {
            AVCaptureDevice.authorizationStatus(for: .video)
        },
        requestAccess: @escaping () async -> Bool = {
            await AVCaptureDevice.requestAccess(for: .video)
        },
        isScannerAvailable: @escaping @MainActor () -> Bool = {
            DataScannerViewController.isSupported && DataScannerViewController.isAvailable
        },
        parser: ExpiryDateParser = ExpiryDateParser(),
        now: @escaping () -> Date = Date.init,
        recognizeItem: @escaping (UIImage) async -> ItemRecognition? = { await ItemPhotoRecognizer.recognize($0) }
    ) {
        self.authorizationStatus = authorizationStatus
        self.requestAccess = requestAccess
        self.isScannerAvailable = isScannerAvailable
        self.parser = parser
        self.now = now
        self.recognizeItem = recognizeItem
        typedDate = Calendar.current.date(byAdding: .day, value: 7, to: now()) ?? now()
    }

    // MARK: - Derived state

    var isCameraLive: Bool { cameraState == .running }

    /// The confirm step needs a name and a date; everything else has a default.
    var canConfirm: Bool {
        !draft.name.trimmingCharacters(in: .whitespaces).isEmpty && draft.expirationDate != nil
    }

    /// When the 2-day-before reminder will fire for the drafted expiry.
    var alertDate: Date? {
        draft.expirationDate.flatMap { Calendar.current.date(byAdding: .day, value: -2, to: $0) }
    }

    /// The estimate the "no date printed" path would use for the current category.
    var estimatedExpiry: Date {
        ShelfLifeEstimator.estimatedExpiry(for: draft.category, from: now())
    }

    /// Whole days from today to `date` (for "7 days from today" captions).
    func daysFromToday(to date: Date) -> Int {
        let calendar = Calendar.current
        return calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: now()),
            to: calendar.startOfDay(for: date)
        ).day ?? 0
    }

    // MARK: - Camera

    /// Starts the camera if permitted, prompts when permission has not been decided
    /// yet, and otherwise records why scanning is not possible in ``cameraState``.
    func startScanning() {
        switch authorizationStatus() {
        case .authorized:
            activateScanner()
        case .notDetermined:
            Task { [weak self] in
                guard let self else { return }
                if await self.requestAccess() {
                    self.activateScanner()
                } else {
                    self.cameraState = .denied
                }
            }
        case .denied, .restricted:
            cameraState = .denied
        @unknown default:
            cameraState = .denied
        }
    }

    func stopScanning() {
        if cameraState == .running { cameraState = .idle }
    }

    private func activateScanner() {
        cameraState = isScannerAvailable() ? .running : .unavailable
    }

    func toggleFlash() {
        // VisionKit's data scanner owns the capture session out-of-process and
        // exposes no torch control, so we configure the device ourselves. Only do
        // so while the camera is actually running and the torch is currently
        // usable — locking the framework-owned device otherwise trips the
        // FigCaptureSourceRemote assert (err=-17281).
        guard cameraState == .running,
              let device = AVCaptureDevice.default(for: .video),
              device.hasTorch, device.isTorchAvailable else { return }
        do {
            try device.lockForConfiguration()
            isFlashOn.toggle()
            device.torchMode = isFlashOn ? .on : .off
            device.unlockForConfiguration()
        } catch {}
    }

    // MARK: - Step 1: photo

    /// Captures a still and names the item from it, then advances to the date
    /// step. If nothing can be recognized (or there's no camera) it still advances
    /// with an empty name for the user to fill in on the confirm step.
    func capturePhoto() {
        guard step == .photo, !isCapturing else { return }
        Task { await performCapture() }
    }

    /// The async body of ``capturePhoto()``, separated so tests can await it.
    func performCapture() async {
        guard step == .photo, !isCapturing else { return }
        isCapturing = true
        defer { isCapturing = false }

        // Capture a still (nil on the simulator / when no camera), then name it.
        var result: ItemRecognition?
        if let image = await camera.capture?() {
            result = await recognizeItem(image)
        }

        if let result {
            draft.name = result.name
            if let category = result.category { draft.category = category }
            recognitionNote = result.note
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            recognitionNote = nil
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
        advance(to: .date)
    }

    /// Skips the photo for items the user would rather name by hand.
    func skipPhoto() {
        guard step == .photo else { return }
        advance(to: .date)
    }

    // MARK: - Step 2: date

    /// Accepts recognized label text only while scanning for a date, and keeps
    /// the first plausible date it finds as the candidate to confirm.
    func handleRecognizedText(_ transcript: String) {
        guard step == .date, dateEntryMode == .scanning, recognizedDate == nil,
              let date = parser.date(in: transcript) else { return }
        recognizedDate = date
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func useRecognizedDate() {
        guard let recognizedDate else { return }
        draft.expirationDate = recognizedDate
        draft.isEstimatedExpiry = false
        advance(to: .confirm)
    }

    func startTypingDate() {
        dateEntryMode = .typing
    }

    func useTypedDate() {
        draft.expirationDate = typedDate
        draft.isEstimatedExpiry = false
        advance(to: .confirm)
    }

    func startEstimating() {
        dateEntryMode = .estimating
    }

    /// Uses the category shelf-life estimate and tags the item as estimated.
    func useEstimate() {
        draft.expirationDate = estimatedExpiry
        draft.isEstimatedExpiry = true
        advance(to: .confirm)
    }

    /// Dismisses the candidate so the camera looks for another date.
    func rescanDate() {
        recognizedDate = nil
        dateEntryMode = .scanning
    }

    // MARK: - Navigation

    func goBack() {
        switch step {
        case .photo:
            break
        case .date:
            recognizedDate = nil
            dateEntryMode = .scanning
            advance(to: .photo)
        case .confirm:
            advance(to: .date)
        }
    }

    private func advance(to next: Step) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            step = next
        }
    }

    // MARK: - Step 3: confirm

    /// The finished item, ready for ``FoodStore/addScanned(_:)``.
    func makeResult() -> ScanResult {
        ScanResult(
            productName: draft.name.trimmingCharacters(in: .whitespaces),
            brand: draft.brand,
            expirationDate: draft.expirationDate,
            barcode: draft.barcode,
            placement: draft.placement,
            category: draft.category,
            isEstimatedExpiry: draft.isEstimatedExpiry
        )
    }

    /// Clears everything for the next scan.
    func reset() {
        draft = Draft()
        recognizedDate = nil
        dateEntryMode = .scanning
        recognitionNote = nil
        step = .photo
    }
}
