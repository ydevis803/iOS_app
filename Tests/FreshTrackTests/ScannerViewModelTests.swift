import AVFoundation
import XCTest
@testable import FreshTrack

@MainActor
final class ScannerViewModelTests: XCTestCase {
    /// Polls until the view model leaves `.idle` or the timeout elapses.
    private func waitForState(_ viewModel: ScannerViewModel, timeout: TimeInterval = 2) async {
        let deadline = Date().addingTimeInterval(timeout)
        while viewModel.cameraState == .idle && Date() < deadline {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }

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
            requestAccess: { requested = true; return true }
        )

        viewModel.startScanning()
        await waitForState(viewModel)

        XCTAssertTrue(requested)
        // On the simulator there is no camera, so a granted request ends in
        // `.unavailable`; on a device it would be `.running`.
        XCTAssertTrue([ScannerViewModel.CameraState.running, .unavailable].contains(viewModel.cameraState), "\(viewModel.cameraState)")
    }

    func testAuthorizedStatusSkipsThePrompt() async {
        var requested = false
        let viewModel = ScannerViewModel(
            authorizationStatus: { .authorized },
            requestAccess: { requested = true; return true }
        )

        viewModel.startScanning()
        await waitForState(viewModel)

        XCTAssertFalse(requested)
        XCTAssertTrue([ScannerViewModel.CameraState.running, .unavailable].contains(viewModel.cameraState), "\(viewModel.cameraState)")
    }

    func testConfirmAndResetClearsScanState() {
        let viewModel = ScannerViewModel(authorizationStatus: { .denied }, requestAccess: { false })
        viewModel.scanResult = ScanResult(productName: "Milk", expirationDate: nil, barcode: "1")
        viewModel.showConfirmation = true

        viewModel.confirmAndReset()

        XCTAssertNil(viewModel.scanResult)
        XCTAssertFalse(viewModel.showConfirmation)
    }
}
