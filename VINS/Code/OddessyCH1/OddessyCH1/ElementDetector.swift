import CoreML
import Vision
import CoreGraphics

// MARK: - One detected UI element

nonisolated struct Detection: Identifiable, Sendable {
    let id = UUID()
    let label: String        // e.g. "TextButton", "Icon", "Text"
    let confidence: Float    // 0–1
    let box: CGRect          // fractions 0–1 of the screenshot, top-left origin (for drawing)
    let rectPt: CGRect       // the same box in points (for HIG rules like 44 pt tap targets)
}

nonisolated enum DetectorError: Error {
    case modelMissing
}

// MARK: - Runs the YOLO model (HIGElementDetector.mlpackage) on a screenshot
//
// The model was trained on letterboxed images: the screenshot is scaled to fit
// the model's input without stretching, and the leftover space is padded with grey.
// iPhone screenshots (1179 × 2556) are taller than the model input (736 × 1280),
// so we add that padding ourselves, then map the boxes back to the original screenshot.

nonisolated final class ElementDetector: @unchecked Sendable {

    // Loaded once, on first use (the model takes a moment to load).
    static let shared: Result<ElementDetector, Error> = Result { try ElementDetector() }

    // The 10 classes the model knows. (The model file pads its label list to 80;
    // anything not in this set is ignored.)
    static let classes: Set<String> = [
        "BackgroundImage", "CheckedTextView", "EditText", "Icon", "Image",
        "PageIndicator", "Switch", "Text", "TextButton", "UpperTaskBar",
    ]

    // Per-class confidence cut-offs. EditText is stricter because the model
    // tends to mistake iOS list rows and cards for text fields at low confidence.
    static let minConfidence: [String: Float] = ["EditText": 0.75]
    static let defaultMinConfidence: Float = 0.35

    private let vnModel: VNCoreMLModel
    private let inputSize: CGSize   // model input in pixels (width × height)

    init() throws {
        guard let url = Bundle.main.url(forResource: "HIGElementDetector", withExtension: "mlmodelc") else {
            throw DetectorError.modelMissing
        }
        let config = MLModelConfiguration()
        config.computeUnits = .all   // CPU + GPU + Neural Engine
        let mlModel = try MLModel(contentsOf: url, configuration: config)

        let constraint = mlModel.modelDescription.inputDescriptionsByName["image"]?.imageConstraint
        inputSize = CGSize(width: constraint?.pixelsWide ?? 736, height: constraint?.pixelsHigh ?? 1280)

        vnModel = try VNCoreMLModel(for: mlModel)
        // Overlap allowed between two boxes of the same class before one is removed.
        // The model's default (0.7) lets through too many near-duplicates.
        vnModel.featureProvider = Thresholds(iou: 0.45, confidence: 0.25)
    }

    /// Detects UI elements. `scale` is the screen scale (3 on recent iPhones) used to convert pixels to points.
    /// Slow-ish (a few hundred ms): call it off the main thread.
    func detect(in cgImage: CGImage, scale: Double) throws -> [Detection] {
        let (padded, imageRect) = letterbox(cgImage)

        let request = VNCoreMLRequest(model: vnModel)
        request.imageCropAndScaleOption = .scaleFill   // padded image already has the model's shape
        try VNImageRequestHandler(cgImage: padded, options: [:]).perform([request])
        let observations = request.results as? [VNRecognizedObjectObservation] ?? []

        let W = Double(cgImage.width), H = Double(cgImage.height)
        let PW = Double(padded.width), PH = Double(padded.height)
        let screenshotPx = CGRect(x: 0, y: 0, width: W, height: H)

        return observations.compactMap { observation -> Detection? in
            guard let top = observation.labels.first, Self.classes.contains(top.identifier) else { return nil }
            let cutoff = Self.minConfidence[top.identifier] ?? Self.defaultMinConfidence
            guard top.confidence >= cutoff else { return nil }

            // Vision boxes: fractions of the padded image, bottom-left origin.
            // Convert to pixels of the original screenshot, top-left origin.
            let b = observation.boundingBox
            let px = CGRect(x: b.minX * PW - imageRect.minX,
                            y: (1 - b.maxY) * PH - imageRect.minY,
                            width: b.width * PW,
                            height: b.height * PH)
                .intersection(screenshotPx)
            guard !px.isNull, px.width > 1, px.height > 1 else { return nil }

            return Detection(
                label: top.identifier,
                confidence: top.confidence,
                box: CGRect(x: px.minX / W, y: px.minY / H, width: px.width / W, height: px.height / H),
                rectPt: CGRect(x: px.minX / scale, y: px.minY / scale,
                               width: px.width / scale, height: px.height / scale)
            )
        }
        .sorted { ($0.box.minY, $0.box.minX) < ($1.box.minY, $1.box.minX) }
    }

    /// Pads the image with grey (like YOLO's training) so it has the model's aspect ratio.
    /// Returns the padded image and where the original sits inside it (pixels, top-left origin).
    private func letterbox(_ image: CGImage) -> (CGImage, CGRect) {
        let W = CGFloat(image.width), H = CGFloat(image.height)
        let original = CGRect(x: 0, y: 0, width: W, height: H)
        let targetAspect = inputSize.width / inputSize.height

        var PW = W, PH = H
        if W / H < targetAspect { PW = (H * targetAspect).rounded() }   // too tall → pad left/right
        else { PH = (W / targetAspect).rounded() }                       // too wide → pad top/bottom
        let x = ((PW - W) / 2).rounded(), y = ((PH - H) / 2).rounded()

        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: Int(PW), height: Int(PH),
                                      bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { return (image, original) }

        context.setFillColor(CGColor(srgbRed: 114 / 255, green: 114 / 255, blue: 114 / 255, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: PW, height: PH))
        // Core Graphics draws with a bottom-left origin.
        context.draw(image, in: CGRect(x: x, y: PH - y - H, width: W, height: H))

        guard let padded = context.makeImage() else { return (image, original) }
        return (padded, CGRect(x: x, y: y, width: W, height: H))
    }
}

// Supplies the model's optional threshold inputs.
nonisolated private final class Thresholds: NSObject, MLFeatureProvider {
    let iou: Double, confidence: Double
    init(iou: Double, confidence: Double) { self.iou = iou; self.confidence = confidence }

    var featureNames: Set<String> { ["iouThreshold", "confidenceThreshold"] }

    func featureValue(for featureName: String) -> MLFeatureValue? {
        switch featureName {
        case "iouThreshold": return MLFeatureValue(double: iou)
        case "confidenceThreshold": return MLFeatureValue(double: confidence)
        default: return nil
        }
    }
}
