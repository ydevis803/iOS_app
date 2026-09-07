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
        case barcode
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

    @Published private(set) var step: Step = .barcode
    @Published var draft = Draft()
    @Published var dateEntryMode: DateEntryMode = .scanning
    /// A date read from the label, shown for confirmation before it is used.
    @Published private(set) var recognizedDate: Date?
    @Published var typedDate: Date
    @Published private(set) var cameraState: CameraState = .idle
    @Published var isFlashOn = false

    private let authorizationStatus: () -> AVAuthorizationStatus
    private let requestAccess: () async -> Bool
    private let isScannerAvailable: @MainActor () -> Bool
    private let parser: ExpiryDateParser
    private let now: () -> Date
    private var lastBarcode: String?

    /// - Parameters:
    ///   - authorizationStatus: Camera permission lookup (defaults to `AVCaptureDevice`).
    ///   - requestAccess: Camera permission prompt (defaults to `AVCaptureDevice`).
    ///   - isScannerAvailable: Whether VisionKit's data scanner can run on this device.
    ///   - parser: Expiry-date parser applied to recognized label text.
    ///   - now: Clock, injectable for deterministic tests.
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
        now: @escaping () -> Date = Date.init
    ) {
        self.authorizationStatus = authorizationStatus
        self.requestAccess = requestAccess
        self.isScannerAvailable = isScannerAvailable
        self.parser = parser
        self.now = now
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
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            isFlashOn.toggle()
            device.torchMode = isFlashOn ? .on : .off
            device.unlockForConfiguration()
        } catch {}
    }

    // MARK: - Step 1: barcode

    /// Accepts a barcode only on the barcode step, looks up the product, and
    /// moves on to the date step.
    func handleRecognizedBarcode(_ payload: String) {
        guard step == .barcode, payload != lastBarcode else { return }
        lastBarcode = payload
        draft.barcode = payload
        if let product = ProductCatalog.lookup(barcode: payload) {
            draft.name = product.name
            draft.brand = product.brand
            draft.category = product.category
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        advance(to: .date)
    }

    /// Loose produce and unpackaged items have no barcode.
    func skipBarcode() {
        guard step == .barcode else { return }
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
        case .barcode:
            break
        case .date:
            recognizedDate = nil
            dateEntryMode = .scanning
            advance(to: .barcode)
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
        lastBarcode = nil
        step = .barcode
    }
}

// MARK: - Product lookup

/// Barcode → product details. A local demo table for now; a production build
/// would query a service such as Open Food Facts.
enum ProductCatalog {
    struct Product: Equatable {
        let name: String
        let brand: String
        let category: FoodCategory
    }

    private static let byPrefix: [String: Product] = [
        "049000": Product(name: "Coca-Cola", brand: "The Coca-Cola Company", category: .beverage),
        "041570": Product(name: "Almond Milk", brand: "Nature's Best", category: .beverage),
        "021130": Product(name: "Dannon Yogurt", brand: "Dannon", category: .dairy)
    ]

    /// Looks a barcode up by its manufacturer prefix.
    static func lookup(barcode: String) -> Product? {
        byPrefix[String(barcode.prefix(6))]
    }
}
