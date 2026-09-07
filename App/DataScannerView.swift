import SwiftUI
import Vision
import VisionKit

/// Hosts VisionKit's `DataScannerViewController`, which recognizes barcodes and
/// printed text in a single camera session. Recognized items are forwarded to the
/// closures; the caller decides which kind it is currently interested in.
struct DataScannerView: UIViewControllerRepresentable {
    /// Scanning runs while `true` and pauses otherwise (e.g. on the confirm step).
    let isActive: Bool
    let onBarcode: @MainActor (String) -> Void
    let onText: @MainActor (String) -> Void

    static let symbologies: [VNBarcodeSymbology] = [
        .ean8, .ean13, .upce, .code128, .code39, .code93, .itf14, .dataMatrix, .qr
    ]

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: Self.symbologies), .text()],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: true,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: false,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {
        context.coordinator.parent = self
        if isActive, !controller.isScanning {
            try? controller.startScanning()
        } else if !isActive, controller.isScanning {
            controller.stopScanning()
        }
    }

    static func dismantleUIViewController(_ controller: DataScannerViewController, coordinator: Coordinator) {
        controller.stopScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    /// Bridges delegate callbacks to the SwiftUI closures.
    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var parent: DataScannerView

        init(parent: DataScannerView) { self.parent = parent }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            forward(addedItems)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            // Text transcripts refine over a few frames; keep feeding them.
            forward(updatedItems.filter { if case .text = $0 { return true } else { return false } })
        }

        private func forward(_ items: [RecognizedItem]) {
            for item in items {
                switch item {
                case .barcode(let barcode):
                    if let payload = barcode.payloadStringValue { parent.onBarcode(payload) }
                case .text(let text):
                    parent.onText(text.transcript)
                @unknown default:
                    break
                }
            }
        }
    }
}
