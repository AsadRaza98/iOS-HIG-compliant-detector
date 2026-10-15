import Observation
import UIKit

@MainActor
@Observable
final class Analyzer {
    enum State {
        case idle
        case analyzing
        case done(AnalysisResult)
        case failed(String)
    }

    var state: State = .idle

    func analyze(_ image: UIImage) async {
        state = .analyzing
        do {
            let result = try await Task.detached(priority: .userInitiated) {
                try Analyzer.run(image)
            }.value
            state = .done(result)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func fail(_ message: String) {
        state = .failed(message)
    }

    // MARK: - Pipeline (runs off the main thread)

    nonisolated static func run(_ uiImage: UIImage) throws -> AnalysisResult {
        guard let cgImage = upright(uiImage) else { throw DetectorError.unreadableImage }
        let size = CGSize(width: cgImage.width, height: cgImage.height)

        let detector = try ElementDetector()
        var elements = try detector.detect(in: cgImage)

        // A screen has at most one tab bar. Keep the lowest one; others are usually
        // cards or toolbars mistaken for a tab bar.
        let tabBars = elements.filter { $0.kind == .tabBar }
        if tabBars.count > 1, let lowest = tabBars.max(by: { $0.rect.maxY < $1.rect.maxY }) {
            elements.removeAll { $0.kind == .tabBar && $0.id != lowest.id }
        }

        // Number elements in reading order so findings can refer to "Button 2" etc.
        elements.sort { ($0.rect.minY, $0.rect.minX) < ($1.rect.minY, $1.rect.minX) }
        var counters: [ElementKind: Int] = [:]
        for i in elements.indices {
            counters[elements[i].kind, default: 0] += 1
            elements[i].index = counters[elements[i].kind]!
        }

        let texts = ElementDetector.recognizeText(in: cgImage)
        let scale = pointScale(forPixelWidth: cgImage.width)
        let rules = HIGRules(elements: elements, texts: texts, sampler: PixelSampler(image: cgImage),
                             pointScale: scale, screenSize: size)

        return AnalysisResult(image: UIImage(cgImage: cgImage), pixelSize: size, pointScale: scale,
                              elements: elements, findings: rules.evaluate())
    }

    /// iPhone screenshots up to 828 px wide are @2x; wider ones are @3x.
    nonisolated static func pointScale(forPixelWidth width: Int) -> CGFloat {
        width <= 828 ? 2 : 3
    }

    /// Returns the image as an upright CGImage at its full pixel size.
    nonisolated static func upright(_ image: UIImage) -> CGImage? {
        if image.imageOrientation == .up, let cgImage = image.cgImage { return cgImage }
        let size = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }.cgImage
    }
}
