import CoreGraphics

// MARK: - Reading pixels
// Draws the screenshot into a plain RGBA buffer once, so we can read
// any pixel's color afterwards. Drawing into an sRGB context also
// converts Display P3 screenshots to sRGB, which the contrast formula expects.

struct PixelReader {
    let width: Int
    let height: Int
    private let bytes: [UInt8]   // 4 bytes per pixel: R, G, B, A. Row 0 is the top.

    init?(cgImage: CGImage) {
        let width = cgImage.width, height = cgImage.height
        self.width = width
        self.height = height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)

        let drew = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let space = CGColorSpace(name: CGColorSpace.sRGB),
                  let context = CGContext(data: buffer.baseAddress,
                                          width: width, height: height,
                                          bitsPerComponent: 8, bytesPerRow: width * 4,
                                          space: space,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drew else { return nil }
        self.bytes = bytes
    }

    // Relative luminance (WCAG): 0 = black, 1 = white.
    func luminance(x: Int, y: Int) -> Double {
        let i = (y * width + x) * 4
        let r = linear(bytes[i]), g = linear(bytes[i + 1]), b = linear(bytes[i + 2])
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    // sRGB values are gamma-encoded; undo that so brightness adds up correctly.
    private func linear(_ value: UInt8) -> Double {
        let c = Double(value) / 255
        return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }
}

// MARK: - Contrast inside one text box
// A text box holds two colors: the background (most pixels) and the text.
// Sorting the pixels by brightness puts one color at each end, so we take
// the 5th percentile as "dark" and the 95th as "light". Using percentiles
// instead of min/max ignores stray pixels and soft anti-aliased edges.

func contrastRatio(in box: CGRect, pixels: PixelReader) -> Double? {
    let bounds = CGRect(x: 0, y: 0, width: pixels.width, height: pixels.height)
    let rect = CGRect(x: box.minX * Double(pixels.width),
                      y: box.minY * Double(pixels.height),
                      width: box.width * Double(pixels.width),
                      height: box.height * Double(pixels.height))
        .integral
        .intersection(bounds)

    var lums: [Double] = []
    for y in Int(rect.minY)..<Int(rect.maxY) {
        for x in Int(rect.minX)..<Int(rect.maxX) {
            lums.append(pixels.luminance(x: x, y: y))
        }
    }
    guard lums.count >= 20 else { return nil }   // too small to judge

    lums.sort()
    let dark = lums[Int(Double(lums.count - 1) * 0.05)]
    let light = lums[Int(Double(lums.count - 1) * 0.95)]

    // WCAG contrast ratio: 1 (same color) up to 21 (black on white).
    return (light + 0.05) / (dark + 0.05)
}

// MARK: - The rule
// Apple's accessibility guidance (from WCAG AA): at least 4.5:1 for text,
// 3:1 for large text (18pt and up). We can't detect bold, so bold
// 14–17pt text is held to the stricter 4.5:1.

func minimumContrast(forSizePt size: Double) -> Double {
    size >= 18 ? 3 : 4.5
}

extension TextItem {
    var passesContrast: Bool? {
        guard let contrast else { return nil }
        return contrast >= minimumContrast(forSizePt: sizePt)
    }
}
