import SwiftUI
import UIKit
import Vision
import VisionKit

/// Hosts VisionKit's `DataScannerViewController` for two jobs: live text
/// recognition (used to read a printed best-before date) and, on demand, a
/// high-resolution still capture that we run on-device recognition over to name
/// the item. Barcode reading was removed in favor of the photo flow.
struct DataScannerView: UIViewControllerRepresentable {
    /// Scanning runs while `true` and pauses otherwise (e.g. on the confirm step).
    let isActive: Bool
    /// Bridge the view model uses to trigger a still capture.
    let camera: ScannerCamera
    let onText: @MainActor (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            // We draw only a static target overlay (no per-item custom highlights
            // that must track geometry), so high-frame-rate tracking isn't needed.
            // It adds capture-pipeline reconfiguration churn that contributes to
            // the FigCaptureSourceRemote err=-17281 log.
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: false,
            isHighlightingEnabled: false
        )
        controller.delegate = context.coordinator
        // Expose the controller's photo capture to the view model.
        camera.capture = { [weak controller] in
            guard let controller else { return nil }
            return try? await controller.capturePhoto()
        }
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

    /// Bridges the live text-recognition delegate callbacks to the SwiftUI closure.
    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var parent: DataScannerView

        init(parent: DataScannerView) { self.parent = parent }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            forward(addedItems)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            // Text transcripts refine over a few frames; keep feeding them.
            forward(updatedItems)
        }

        private func forward(_ items: [RecognizedItem]) {
            for item in items {
                if case .text(let text) = item { parent.onText(text.transcript) }
            }
        }
    }
}

// MARK: - Camera Bridge

/// A small bridge that lets the view model trigger a still capture on the
/// VisionKit controller that ``DataScannerView`` owns. The representable assigns
/// ``capture`` when it creates the controller.
@MainActor
final class ScannerCamera {
    /// Captures a high-resolution still from the live camera, or `nil` when no
    /// camera is available (e.g. the simulator) or the capture fails.
    var capture: (@MainActor () async -> UIImage?)?
}

// MARK: - Item Photo Recognition

/// The outcome of naming an item from a photo, and how the name was obtained.
struct ItemRecognition: Equatable {
    enum Source { case label, classified }
    let name: String
    let category: FoodCategory?
    let source: Source

    /// A short caption explaining where the name came from.
    var note: String {
        switch source {
        case .label: return "Read from the label"
        case .classified: return "Recognized from the photo"
        }
    }
}

/// On-device recognition of a food item's name from a still photo. It first runs
/// OCR to read a printed label, and if no usable label text is found it falls back
/// to image classification to name loose produce. Everything runs on device via
/// the Vision framework — no network, no API keys.
enum ItemPhotoRecognizer {
    static func recognize(_ image: UIImage) async -> ItemRecognition? {
        guard let cgImage = image.cgImage else { return nil }
        // Vision's handlers are synchronous and can block; run them off the main actor.
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: analyze(cgImage))
            }
        }
    }

    private static func analyze(_ cgImage: CGImage) -> ItemRecognition? {
        if let name = labelName(from: cgImage) {
            return ItemRecognition(name: name, category: category(for: name), source: .label)
        }
        if let (name, category) = classified(from: cgImage) {
            return ItemRecognition(name: name, category: category, source: .classified)
        }
        return nil
    }

    // MARK: OCR — packaged labels

    private static func labelName(from cgImage: CGImage) -> String? {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        guard (try? handler.perform([request])) != nil,
              let observations = request.results, !observations.isEmpty else { return nil }

        // The product name is usually the most prominent line, so prefer taller
        // text after discarding dates, weights, and other non-name noise.
        let candidates: [(text: String, height: CGFloat)] = observations.compactMap { obs in
            guard let text = obs.topCandidates(1).first?.string else { return nil }
            return (text, obs.boundingBox.height)
        }
        let names = candidates
            .filter { isPlausibleName($0.text) }
            .sorted { $0.height > $1.height }
        guard let best = names.first, best.height >= 0.03 else { return nil }
        return normalize(best.text)
    }

    /// Rejects lines that are dates, quantities, URLs, or otherwise clearly not a name.
    private static func isPlausibleName(_ raw: String) -> Bool {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 3 else { return false }
        let letters = text.filter(\.isLetter).count
        guard letters >= 3 else { return false }
        // Mostly-digit lines (weights, dates, barcodes) are not names.
        let digits = text.filter(\.isNumber).count
        if Double(digits) > Double(text.count) * 0.4 { return false }
        let lowered = text.lowercased()
        let noise = ["best by", "best before", "use by", "sell by", "exp", "net wt",
                     "net weight", "www", ".com", "ingredients", "nutrition"]
        return !noise.contains { lowered.contains($0) }
    }

    private static func normalize(_ raw: String) -> String {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // Title-case ALL-CAPS label text so it reads naturally on the card.
        let isAllCaps = text.rangeOfCharacter(from: .lowercaseLetters) == nil
        return isAllCaps ? text.capitalized : text
    }

    // MARK: Classification — loose produce

    private static func classified(from cgImage: CGImage) -> (String, FoodCategory?)? {
        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        guard (try? handler.perform([request])) != nil,
              let observations = request.results else { return nil }

        let ranked = observations
            .filter { $0.hasMinimumRecall(0.01, forPrecision: 0.9) }
            .sorted { $0.confidence > $1.confidence }
        // Prefer a specific identifier over generic taxonomy nodes like "food".
        let generic: Set<String> = ["food", "fruit", "vegetable", "produce", "plant",
                                    "ingredient", "meal", "dish", "snack_food"]
        let best = ranked.first { !generic.contains($0.identifier.lowercased()) && $0.confidence >= 0.15 }
            ?? ranked.first { $0.confidence >= 0.4 }
        guard let identifier = best?.identifier else { return nil }
        let name = identifier.replacingOccurrences(of: "_", with: " ").capitalized
        return (name, category(for: identifier))
    }

    // MARK: Category mapping

    /// Best-effort mapping from a recognized name to a ``FoodCategory`` so the
    /// estimate step and card icon start from a sensible default.
    private static func category(for name: String) -> FoodCategory? {
        let n = name.lowercased()
        let map: [(keys: [String], category: FoodCategory)] = [
            (["milk", "cheese", "yogurt", "yoghurt", "butter", "cream"], .dairy),
            (["apple", "banana", "orange", "berry", "grape", "lemon", "lime", "pear",
              "peach", "melon", "tomato", "lettuce", "spinach", "carrot", "pepper",
              "onion", "potato", "broccoli", "cucumber", "avocado", "fruit", "vegetable", "produce"], .produce),
            (["beef", "chicken", "pork", "steak", "meat", "fish", "salmon", "turkey"], .meat),
            (["bread", "bagel", "cake", "pastry", "muffin", "croissant"], .bakery),
            (["juice", "soda", "water", "coffee", "tea", "beverage", "drink", "cola"], .beverage),
            (["rice", "pasta", "cereal", "grain", "oat", "flour"], .grain)
        ]
        return map.first { entry in entry.keys.contains { n.contains($0) } }?.category
    }
}
