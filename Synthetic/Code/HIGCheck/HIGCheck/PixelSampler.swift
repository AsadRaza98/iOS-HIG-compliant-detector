import CoreGraphics
import Foundation

struct RGB {
    let r: Double, g: Double, b: Double

    /// WCAG relative luminance.
    var luminance: Double {
        func channel(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
    }

    /// WCAG contrast ratio, from 1:1 to 21:1.
    func contrast(with other: RGB) -> Double {
        let a = luminance, b = other.luminance
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }
}

struct ContrastSample {
    let ratio: Double
    let foreground: RGB
    let background: RGB
}

/// Reads pixel colours from the screenshot to estimate text contrast.
struct PixelSampler {
    let width: Int
    let height: Int
    private let pixels: [UInt8]

    init?(image: CGImage) {
        let width = image.width
        let height = image.height
        var buffer = [UInt8](repeating: 0, count: width * height * 4)
        let drawn: Bool = buffer.withUnsafeMutableBytes { raw in
            guard let context = CGContext(
                data: raw.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
        self.width = width
        self.height = height
        self.pixels = buffer
    }

    /// Finds the dominant colour in `rect` (the background) and the colour that contrasts
    /// most with it among colours covering at least 2% of the area (usually the text).
    func contrast(in rect: CGRect) -> ContrastSample? {
        let bounds = rect.integral.intersection(CGRect(x: 0, y: 0, width: width, height: height))
        guard !bounds.isNull, bounds.width >= 4, bounds.height >= 4 else { return nil }

        let stepX = max(1, Int(bounds.width) / 80)
        let stepY = max(1, Int(bounds.height) / 40)
        var buckets: [Int: (count: Int, r: Double, g: Double, b: Double)] = [:]
        var total = 0

        var y = Int(bounds.minY)
        while y < Int(bounds.maxY) {
            var x = Int(bounds.minX)
            while x < Int(bounds.maxX) {
                let i = (y * width + x) * 4
                let r = Int(pixels[i]), g = Int(pixels[i + 1]), b = Int(pixels[i + 2])
                let key = (r >> 4) << 8 | (g >> 4) << 4 | (b >> 4)
                var bucket = buckets[key] ?? (0, 0, 0, 0)
                bucket.count += 1
                bucket.r += Double(r); bucket.g += Double(g); bucket.b += Double(b)
                buckets[key] = bucket
                total += 1
                x += stepX
            }
            y += stepY
        }
        guard total > 0 else { return nil }

        func average(_ bucket: (count: Int, r: Double, g: Double, b: Double)) -> RGB {
            let n = Double(bucket.count) * 255
            return RGB(r: bucket.r / n, g: bucket.g / n, b: bucket.b / n)
        }

        guard let backgroundBucket = buckets.values.max(by: { $0.count < $1.count }) else { return nil }
        let background = average(backgroundBucket)
        let minimumCount = max(2, total / 50)

        var best: (ratio: Double, color: RGB)?
        for bucket in buckets.values where bucket.count >= minimumCount {
            let color = average(bucket)
            let ratio = color.contrast(with: background)
            if best == nil || ratio > best!.ratio { best = (ratio, color) }
        }
        guard let best, best.ratio > 1.05 else { return nil }   // single flat colour: nothing to measure
        return ContrastSample(ratio: best.ratio, foreground: best.color, background: background)
    }
}
