import CoreML
import Vision
import UIKit

enum DetectorError: LocalizedError {
    case modelMissing
    case unreadableImage

    var errorDescription: String? {
        switch self {
        case .modelMissing:
            return "The detection model is missing. Add HIGDetector.mlpackage to the HIGCheck folder in Xcode, then build again."
        case .unreadableImage:
            return "This image couldn't be read."
        }
    }
}

/// Runs the YOLO model (exported from the Colab notebook) through Vision.
final class ElementDetector {
    /// Detections below this confidence are ignored. Most false detections on real
    /// screenshots scored under 0.6.
    static let minimumConfidence: Float = 0.6

    private let model: VNCoreMLModel

    init() throws {
        guard let url = Bundle.main.url(forResource: "HIGDetector", withExtension: "mlmodelc") else {
            throw DetectorError.modelMissing
        }
        let mlModel = try MLModel(contentsOf: url, configuration: MLModelConfiguration())
        model = try VNCoreMLModel(for: mlModel)
        // The exported model includes box filtering (NMS); these are its two tuning inputs.
        model.featureProvider = try? MLDictionaryFeatureProvider(dictionary: [
            "iouThreshold": 0.5,
            "confidenceThreshold": 0.25,
        ])
    }

    func detect(in image: CGImage) throws -> [DetectedElement] {
        let request = VNCoreMLRequest(model: model)
        // The model expects the whole screenshot; it was trained on full screens.
        request.imageCropAndScaleOption = .scaleFill
        try VNImageRequestHandler(cgImage: image, orientation: .up).perform([request])

        let width = image.width
        let height = image.height
        let observations = request.results as? [VNRecognizedObjectObservation] ?? []
        return observations.compactMap { observation in
            guard let label = observation.labels.first,
                  let kind = ElementKind(rawValue: label.identifier),
                  label.confidence >= Self.minimumConfidence else { return nil }
            let box = VNImageRectForNormalizedRect(observation.boundingBox, width, height)
            // Vision uses a bottom-left origin; flip to top-left.
            let rect = CGRect(x: box.minX, y: CGFloat(height) - box.maxY, width: box.width, height: box.height)
            return DetectedElement(kind: kind, rect: rect, confidence: label.confidence)
        }
    }

    /// On-device text recognition, used to find switch labels and tab titles.
    static func recognizeText(in image: CGImage) -> [TextItem] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        try? VNImageRequestHandler(cgImage: image, orientation: .up).perform([request])

        let width = image.width
        let height = image.height
        return (request.results ?? []).compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            let box = VNImageRectForNormalizedRect(observation.boundingBox, width, height)
            let rect = CGRect(x: box.minX, y: CGFloat(height) - box.maxY, width: box.width, height: box.height)
            return TextItem(string: candidate.string, rect: rect)
        }
    }
}
