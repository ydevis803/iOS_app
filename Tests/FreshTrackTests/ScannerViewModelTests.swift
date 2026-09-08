import AVFoundation
import UIKit
import XCTest
@testable import FreshTrack

@MainActor
final class ScannerViewModelTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)
    private lazy var today = calendar.date(from: DateComponents(year: 2026, month: 9, day: 7, hour: 10))!

    /// A view model with an authorized, available camera and a fixed clock.
    /// `recognizeItem` is injectable so the photo-capture flow can be tested.
    private func makeReady(
        scannerAvailable: Bool = true,
        recognizeItem: @escaping (UIImage) async -> ItemRecognition? = { _ in nil }
    ) -> ScannerViewModel {
        let viewModel = ScannerViewModel(
            authorizationStatus: { .authorized },
            requestAccess: { true },
            isScannerAvailable: { scannerAvailable },
            parser: ExpiryDateParser(today: today, locale: Locale(identifier: "en_US"), calendar: calendar),
            now: { [today] in today },
            recognizeItem: recognizeItem
        )
        viewModel.startScanning()
        return viewModel
    }

    /// Polls until the view model leaves `.idle` or the timeout elapses.
    private func waitForState(_ viewModel: ScannerViewModel, timeout: TimeInterval = 2) async {
        let deadline = Date().addingTimeInterval(timeout)
        while viewModel.cameraState == .idle && Date() < deadline {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    // MARK: Camera permission

    func testDeniedStatusDoesNotPromptAgain() async {
        var requested = false
        let viewModel = ScannerViewModel(
            authorizationStatus: { .denied },
            requestAccess: { requested = true; return true }
        )

        viewModel.startScanning()
        await waitForState(viewModel)

        XCTAssertEqual(viewModel.cameraState, .denied)
        XCTAssertFalse(requested, "A denied status cannot be re-prompted; the app must not ask again")
    }

    func testRestrictedStatusIsTreatedAsDenied() async {
        let viewModel = ScannerViewModel(authorizationStatus: { .restricted }, requestAccess: { true })
        viewModel.startScanning()
        await waitForState(viewModel)
        XCTAssertEqual(viewModel.cameraState, .denied)
    }

    func testNotDeterminedStatusPromptsAndHonoursRefusal() async {
        var requested = false
        let viewModel = ScannerViewModel(
            authorizationStatus: { .notDetermined },
            requestAccess: { requested = true; return false }
        )

        viewModel.startScanning()
        await waitForState(viewModel)

        XCTAssertTrue(requested, "First launch must ask for camera access")
        XCTAssertEqual(viewModel.cameraState, .denied)
    }

    func testNotDeterminedStatusPromptsAndStartsWhenGranted() async {
        var requested = false
        let viewModel = ScannerViewModel(
            authorizationStatus: { .notDetermined },
            requestAccess: { requested = true; return true },
            isScannerAvailable: { true }
        )

        viewModel.startScanning()
        await waitForState(viewModel)

        XCTAssertTrue(requested)
        XCTAssertEqual(viewModel.cameraState, .running)
    }

    func testAuthorizedWithoutScannerIsUnavailable() {
        let viewModel = makeReady(scannerAvailable: false)
        XCTAssertEqual(viewModel.cameraState, .unavailable)
        XCTAssertFalse(viewModel.isCameraLive)
    }

    // MARK: Step 1 (photo) → 2 (date) → 3 (confirm)

    func testCapturePrefillsNameAndCategoryThenAdvances() async {
        let recognition = ItemRecognition(name: "Hass Avocado", category: .produce, source: .classified)
        let viewModel = makeReady(recognizeItem: { _ in recognition })
        viewModel.camera.capture = { UIImage() }
        XCTAssertEqual(viewModel.step, .photo)

        await viewModel.performCapture()

        XCTAssertEqual(viewModel.step, .date)
        XCTAssertEqual(viewModel.draft.name, "Hass Avocado")
        XCTAssertEqual(viewModel.draft.category, .produce)
        XCTAssertEqual(viewModel.recognitionNote, "Recognized from the photo")
        XCTAssertFalse(viewModel.isCapturing)
    }

    func testCaptureWithoutACameraStillAdvancesWithEmptyName() async {
        // No `camera.capture` bridge assigned → no image, nothing recognized.
        let viewModel = makeReady()

        await viewModel.performCapture()

        XCTAssertEqual(viewModel.step, .date)
        XCTAssertEqual(viewModel.draft.name, "")
        XCTAssertNil(viewModel.recognitionNote)
    }

    func testCaptureIsIgnoredOutsideThePhotoStep() async {
        let viewModel = makeReady(recognizeItem: { _ in
            ItemRecognition(name: "Should not apply", category: nil, source: .label)
        })
        viewModel.skipPhoto()
        viewModel.camera.capture = { UIImage() }

        await viewModel.performCapture()

        XCTAssertEqual(viewModel.step, .date, "Capturing off the photo step must not advance again")
        XCTAssertEqual(viewModel.draft.name, "")
    }

    func testLabelTextIsParsedOnlyOnTheDateStep() {
        let viewModel = makeReady()
        viewModel.handleRecognizedText("BEST BY 14 SEP 2026")
        XCTAssertNil(viewModel.recognizedDate, "Text on the photo step must be ignored")

        viewModel.skipPhoto()
        viewModel.handleRecognizedText("NET WT 12 OZ")
        XCTAssertNil(viewModel.recognizedDate)

        viewModel.handleRecognizedText("BEST BY 14 SEP 2026")
        XCTAssertEqual(viewModel.recognizedDate.map { calendar.component(.day, from: $0) }, 14)

        // A later, different reading does not replace the candidate awaiting confirmation.
        viewModel.handleRecognizedText("2027-01-01")
        XCTAssertEqual(viewModel.recognizedDate.map { calendar.component(.year, from: $0) }, 2026)
    }

    func testUseRecognizedDateMovesToConfirmWithoutEstimateFlag() {
        let viewModel = makeReady()
        viewModel.skipPhoto()
        viewModel.draft.name = "Almond Milk"
        viewModel.handleRecognizedText("14 SEP 2026")

        viewModel.useRecognizedDate()

        XCTAssertEqual(viewModel.step, .confirm)
        XCTAssertFalse(viewModel.draft.isEstimatedExpiry)
        XCTAssertEqual(viewModel.draft.expirationDate.map { calendar.component(.day, from: $0) }, 14)
        XCTAssertTrue(viewModel.canConfirm)
        XCTAssertEqual(viewModel.alertDate.map { calendar.component(.day, from: $0) }, 12)
    }

    func testEstimatePathTagsTheItemAndUsesTheCategory() {
        let viewModel = makeReady()
        viewModel.skipPhoto()
        viewModel.startEstimating()
        viewModel.draft.category = .produce

        XCTAssertEqual(viewModel.daysFromToday(to: viewModel.estimatedExpiry), ShelfLifeEstimator.days(for: .produce))

        viewModel.useEstimate()

        XCTAssertEqual(viewModel.step, .confirm)
        XCTAssertTrue(viewModel.draft.isEstimatedExpiry)
        XCTAssertFalse(viewModel.canConfirm, "An estimated item still needs a name before it can be saved")

        viewModel.draft.name = "Baby Spinach"
        XCTAssertTrue(viewModel.canConfirm)

        let result = viewModel.makeResult()
        XCTAssertEqual(result.productName, "Baby Spinach")
        XCTAssertTrue(result.isEstimatedExpiry)
        XCTAssertEqual(result.category, .produce)
        XCTAssertNil(result.barcode)
    }

    func testTypedDatePath() {
        let viewModel = makeReady()
        viewModel.skipPhoto()
        viewModel.startTypingDate()
        XCTAssertEqual(viewModel.dateEntryMode, .typing)
        viewModel.typedDate = calendar.date(from: DateComponents(year: 2026, month: 12, day: 24))!

        viewModel.useTypedDate()

        XCTAssertEqual(viewModel.step, .confirm)
        XCTAssertFalse(viewModel.draft.isEstimatedExpiry)
        XCTAssertEqual(viewModel.draft.expirationDate.map { calendar.component(.month, from: $0) }, 12)
    }

    func testGoBackRetracesStepsAndClearsTheCandidateDate() {
        let viewModel = makeReady()
        viewModel.skipPhoto()
        viewModel.draft.name = "Almond Milk"
        viewModel.handleRecognizedText("14 SEP 2026")
        viewModel.useRecognizedDate()
        XCTAssertEqual(viewModel.step, .confirm)

        viewModel.goBack()
        XCTAssertEqual(viewModel.step, .date)
        viewModel.goBack()
        XCTAssertEqual(viewModel.step, .photo)
        XCTAssertNil(viewModel.recognizedDate)
        viewModel.goBack()
        XCTAssertEqual(viewModel.step, .photo)
    }

    func testResetClearsEverything() {
        let viewModel = makeReady()
        viewModel.skipPhoto()
        viewModel.draft.name = "Almond Milk"
        viewModel.handleRecognizedText("14 SEP 2026")
        viewModel.useRecognizedDate()

        viewModel.reset()

        XCTAssertEqual(viewModel.step, .photo)
        XCTAssertEqual(viewModel.draft, ScannerViewModel.Draft())
        XCTAssertNil(viewModel.recognizedDate)
        XCTAssertNil(viewModel.recognitionNote)

        // The flow can be driven again after a reset.
        viewModel.skipPhoto()
        XCTAssertEqual(viewModel.step, .date)
    }
}
