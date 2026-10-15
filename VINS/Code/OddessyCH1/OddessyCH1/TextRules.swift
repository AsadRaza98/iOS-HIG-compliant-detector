import CoreGraphics
import Vision

// MARK: - HIG text checks: size and contrast
//
// Reuses the Text tab's building blocks:
//   runVision (ContentView.swift)          – Vision text recognition, one observation per line
//   boxToFontRatio (ContentView.swift)     – Vision box height ÷ real font size (calibrate it!)
//   PixelReader, contrastRatio, minimumContrast (ContrastCheck.swift)
//
//  3. Text size: HIG's smallest recommended size on iOS is 11 pt.          → Warning
//  4. Contrast: at least 4.5:1, or 3:1 for text 18 pt and larger (WCAG AA). → Warning
//
// Skipped, because the measurement isn't meaningful there (tuned on 10 real screenshots):
//  - status-bar text (clock etc.),
//  - text inside an Image / BackgroundImage the detector found (banners, photos, artwork),
//  - text cut off at the very bottom of the screen (content scrolled under the tab bar).

func textIssues(observations: [RecognizedTextObservation], cgImage: CGImage,
                scale: Double, detections: [Detection]) -> [HIGIssue] {
    let W = Double(cgImage.width), H = Double(cgImage.height)
    let screenHeight = H / scale
    let top = HIGRules.topInset(screenHeight: screenHeight)
    let pixels = PixelReader(cgImage: cgImage)
    let artwork = detections.filter { $0.label == "Image" || $0.label == "BackgroundImage" }

    var issues: [HIGIssue] = []

    for observation in observations {
        guard let text = observation.topCandidates(1).first?.string else { continue }
        let box = observation.boundingBox.toImageCoordinates(CGSize(width: 1, height: 1), origin: .upperLeft)
        let rectPt = CGRect(x: box.minX * W / scale, y: box.minY * H / scale,
                            width: box.width * W / scale, height: box.height * H / scale)

        if rectPt.minY < top { continue }                                            // status bar
        if rectPt.maxY > screenHeight - HIGRules.homeIndicatorBand { continue }      // clipped at bottom
        if artwork.contains(where: { HIGRules.contains($0.rectPt, rectPt, pad: 6) }) { continue }

        let sizePt = rectPt.height / boxToFontRatio
        let quoted = "“" + (text.count > 30 ? String(text.prefix(30)) + "…" : text) + "”"

        // Rule 3: text size
        if sizePt < HIGRules.minTextSize - 0.5 {
            issues.append(HIGIssue(
                severity: .warning, rule: "Text size",
                message: "\(quoted) is about \(Int(sizePt.rounded())) pt. HIG recommends at least 11 pt.",
                box: box, rectPt: rectPt))
        }

        // Rule 4: contrast
        if let pixels, let ratio = contrastRatio(in: box, pixels: pixels) {
            let needed = minimumContrast(forSizePt: sizePt)
            if ratio < needed {
                issues.append(HIGIssue(
                    severity: .warning, rule: "Contrast",
                    message: "\(quoted) has contrast \(String(format: "%.1f", ratio)):1; needs at least \(needed == 3 ? "3" : "4.5"):1.",
                    box: box, rectPt: rectPt))
            }
        }
    }
    return issues
}
