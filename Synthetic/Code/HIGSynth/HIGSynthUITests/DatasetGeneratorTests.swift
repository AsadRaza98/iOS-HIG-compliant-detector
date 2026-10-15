import XCTest
import UIKit

/// Launches the HIGSynth app once per seed, takes a screenshot, reads every element's frame
/// from the accessibility tree, and writes a PNG + a Create ML style label file.
///
/// Configure with environment variables. When running through `xcodebuild`, prefix them with
/// `TEST_RUNNER_` (scripts/generate.sh does this for you):
///   HIGSYNTH_COUNT       number of screenshots to make           (default 50)
///   HIGSYNTH_START_SEED  first seed                              (default 0)
///   HIGSYNTH_OUTPUT      output folder on your Mac               (default ~/HIGSynthDataset)
///   HIGSYNTH_MAX_DIM     longest image side in pixels, 0 = full  (default 1600)
///
/// Output:
///   <output>/images/synth_00000042.png
///   <output>/labels/synth_00000042.json
/// Existing label files are skipped, so you can stop and resume at any time.
final class DatasetGeneratorTests: XCTestCase {

    private struct Box {
        let label: String
        let rect: CGRect
        /// True for elements that live inside a nav bar or tab bar (e.g. the search field).
        var insideBar = false
        var identifier = ""
    }

    private static let bottomButtonID = "synth.button.bottom"
    private static let rowID = "synth.row"

    private enum GenerationError: Error {
        case launchTimeout
        case badScreenshot
    }

    /// Weighted Dynamic Type sizes passed to the app at launch.
    private static let contentSizes: [(String, Double)] = [
        ("UICTContentSizeCategoryS", 0.08),
        ("UICTContentSizeCategoryM", 0.12),
        ("UICTContentSizeCategoryL", 0.45),
        ("UICTContentSizeCategoryXL", 0.15),
        ("UICTContentSizeCategoryXXL", 0.10),
        ("UICTContentSizeCategoryXXXL", 0.06),
        ("UICTContentSizeCategoryAccessibilityM", 0.04),
    ]

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    @MainActor
    func testGenerateDataset() throws {
        let env = ProcessInfo.processInfo.environment
        let count = Int(env["HIGSYNTH_COUNT"] ?? "") ?? 50
        let startSeed = UInt64(env["HIGSYNTH_START_SEED"] ?? "") ?? 0
        let maxDimension = CGFloat(Double(env["HIGSYNTH_MAX_DIM"] ?? "") ?? 1600)
        let outputRoot = Self.outputRoot(env)

        let imagesDir = outputRoot.appendingPathComponent("images", isDirectory: true)
        let labelsDir = outputRoot.appendingPathComponent("labels", isDirectory: true)
        try FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: labelsDir, withIntermediateDirectories: true)
        print("HIGSynth: generating \(count) samples from seed \(startSeed) into \(outputRoot.path)")

        let app = XCUIApplication()
        var written = 0
        var failed = 0

        for offset in 0..<count {
            let seed = startSeed + UInt64(offset)
            let name = String(format: "synth_%08llu", seed)
            let labelURL = labelsDir.appendingPathComponent("\(name).json")
            if FileManager.default.fileExists(atPath: labelURL.path) { continue }

            do {
                try autoreleasepool {
                    try captureSample(app: app, seed: seed, name: name,
                                      imagesDir: imagesDir, labelURL: labelURL, maxDimension: maxDimension)
                }
                written += 1
                if written % 25 == 0 { print("HIGSynth: \(written) written so far") }
            } catch {
                failed += 1
                print("HIGSynth: seed \(seed) failed: \(error)")
            }
            app.terminate()
        }
        print("HIGSynth: done. \(written) written, \(failed) failed.")
    }

    // MARK: - One sample

    @MainActor
    private func captureSample(app: XCUIApplication, seed: UInt64, name: String,
                               imagesDir: URL, labelURL: URL, maxDimension: CGFloat) throws {
        // System-level variation (text size, right-to-left) is decided here and passed as
        // launch arguments, so UIKit-backed bars react to it too.
        var rng = TestRNG(seed: seed ^ 0x5DEE_CE66_D1CE_F00D)
        let contentSize = Self.weightedPick(Self.contentSizes, using: &rng)
        let rightToLeft = Double.random(in: 0..<1, using: &rng) < 0.08

        var arguments = ["-seed", String(seed), "-UIPreferredContentSizeCategoryName", contentSize]
        if rightToLeft {
            arguments += ["-AppleTextDirection", "YES", "-NSForceRightToLeftWritingDirection", "YES"]
        }
        app.launchArguments = arguments
        app.launch()
        guard app.wait(for: .runningForeground, timeout: 20) else { throw GenerationError.launchTimeout }
        Thread.sleep(forTimeInterval: 0.8) // let large titles / search bars settle

        let snapshot = try app.snapshot()
        let screenshot = XCUIScreen.main.screenshot()
        let screen = snapshot.frame
        guard screen.width > 0, let cgImage = screenshot.image.cgImage else { throw GenerationError.badScreenshot }

        var boxes: [Box] = []
        collect(snapshot, insideSwitch: false, insideSearch: false, insideBar: false, into: &boxes)
        boxes = dedupe(visible(boxes, in: screen, occluders: occluders(in: boxes, screen: screen)))

        // Points -> pixels, then optional downscale.
        let pixelScale = CGFloat(cgImage.width) / screen.width
        let longSide = CGFloat(max(cgImage.width, cgImage.height))
        let resize = maxDimension > 0 ? min(1, maxDimension / longSide) : 1
        let scale = pixelScale * resize
        let outWidth = Int((CGFloat(cgImage.width) * resize).rounded())
        let outHeight = Int((CGFloat(cgImage.height) * resize).rounded())

        let pngData = resize < 1
            ? Self.resizedPNG(cgImage, width: outWidth, height: outHeight)
            : screenshot.pngRepresentation
        try pngData.write(to: imagesDir.appendingPathComponent("\(name).png"))

        // Create ML format: x/y are the CENTER of the box, in pixels.
        let annotations: [[String: Any]] = boxes.map { box in
            let r = box.rect.offsetBy(dx: -screen.minX, dy: -screen.minY)
            return [
                "label": box.label,
                "coordinates": [
                    "x": Self.round1(r.midX * scale),
                    "y": Self.round1(r.midY * scale),
                    "width": Self.round1(r.width * scale),
                    "height": Self.round1(r.height * scale),
                ],
            ]
        }

        let env = ProcessInfo.processInfo.environment
        let entry: [String: Any] = [
            "image": "\(name).png",
            "annotations": annotations,
            "meta": [
                "seed": seed,
                "contentSize": contentSize,
                "rightToLeft": rightToLeft,
                "device": env["SIMULATOR_DEVICE_NAME"] ?? UIDevice.current.model,
                "runtime": env["SIMULATOR_RUNTIME_VERSION"] ?? UIDevice.current.systemVersion,
                "imageWidth": outWidth,
                "imageHeight": outHeight,
                "pointsToPixels": Self.round1(scale * 100) / 100,
            ],
        ]
        let data = try JSONSerialization.data(withJSONObject: entry, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: labelURL)
    }

    // MARK: - Labelling

    /// Walks the accessibility tree and maps element types to our 8 classes.
    @MainActor
    private func collect(_ element: XCUIElementSnapshot, insideSwitch: Bool, insideSearch: Bool,
                         insideBar: Bool, into boxes: inout [Box]) {
        var label: String?
        switch element.elementType {
        case .navigationBar:
            label = "navBar"
        case .tabBar:
            label = "tabBar"
        case .searchField:
            label = "searchField"
        case .segmentedControl:
            label = "segmentedControl"
        case .switch:
            label = insideSwitch ? nil : "toggle"           // iOS nests a switch inside a switch
        case .textField, .secureTextField:
            label = insideSearch ? nil : "textField"        // ignore the field inside a search bar
        case .cell:
            // Section headers/footers are cells too on recent iOS. Only real rows carry our identifier.
            label = Self.subtreeHasRowID(element) ? "listRow" : nil
        case .button:
            // Only buttons we generated. Tab items, segments and bar buttons belong to their parent class.
            label = element.identifier.hasPrefix("synth.button") ? "button" : nil
        default:
            label = nil
        }
        if let label {
            boxes.append(Box(label: label, rect: element.frame, insideBar: insideBar, identifier: element.identifier))
        }
        let isBar = element.elementType == .navigationBar || element.elementType == .tabBar
        for child in element.children {
            collect(child,
                    insideSwitch: insideSwitch || element.elementType == .switch,
                    insideSearch: insideSearch || element.elementType == .searchField,
                    insideBar: insideBar || isBar,
                    into: &boxes)
        }
    }

    @MainActor
    private static func subtreeHasRowID(_ element: XCUIElementSnapshot) -> Bool {
        if element.identifier.hasPrefix(rowID) { return true }
        return element.children.contains { subtreeHasRowID($0) }
    }

    /// Areas drawn on top of the content: nav bars, tab bars and the pinned bottom-button bar.
    @MainActor
    private func occluders(in boxes: [Box], screen: CGRect) -> [CGRect] {
        var result = boxes
            .filter { $0.label == "navBar" || $0.label == "tabBar" }
            .map { $0.rect.intersection(screen) }
            .filter { !$0.isNull }
        if let bottom = boxes.first(where: { $0.identifier == Self.bottomButtonID }) {
            let top = bottom.rect.minY - 12 // the bar's padding above the button
            result.append(CGRect(x: screen.minX, y: top, width: screen.width, height: screen.maxY - top))
        }
        return result
    }

    /// Clips boxes to the screen, trims away the parts hidden under bars, and drops
    /// anything that ends up less than half visible.
    @MainActor
    private func visible(_ boxes: [Box], in screen: CGRect, occluders: [CGRect]) -> [Box] {
        boxes.compactMap { box in
            let rect = box.rect
            guard rect.width >= 2, rect.height >= 2 else { return nil }
            var clipped = rect.intersection(screen)
            guard !clipped.isNull else { return nil }

            let isOccluder = box.label == "navBar" || box.label == "tabBar" || box.identifier == Self.bottomButtonID
            if !isOccluder && !box.insideBar {
                for bar in occluders where bar.intersects(clipped) {
                    // Bars span the full width, so they cut a box from the top or the bottom.
                    guard bar.minX <= clipped.minX + 1, bar.maxX >= clipped.maxX - 1 else { continue }
                    if bar.midY > clipped.midY {
                        clipped.size.height = max(0, bar.minY - clipped.minY)
                    } else {
                        let newTop = bar.maxY
                        clipped = CGRect(x: clipped.minX, y: newTop, width: clipped.width,
                                         height: max(0, clipped.maxY - newTop))
                    }
                }
            }

            guard clipped.width >= 4, clipped.height >= 4 else { return nil }
            let visibleFraction = (clipped.width * clipped.height) / (rect.width * rect.height)
            guard visibleFraction >= 0.5 else { return nil }
            return Box(label: box.label, rect: clipped, insideBar: box.insideBar, identifier: box.identifier)
        }
    }

    /// Removes near-identical boxes of the same class (the same control reported twice).
    @MainActor
    private func dedupe(_ boxes: [Box]) -> [Box] {
        var result: [Box] = []
        for box in boxes where !result.contains(where: { $0.label == box.label && Self.iou($0.rect, box.rect) > 0.9 }) {
            result.append(box)
        }
        return result
    }

    // MARK: - Helpers

    private static func iou(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let intersection = a.intersection(b)
        if intersection.isNull { return 0 }
        let overlap = intersection.width * intersection.height
        return overlap / (a.width * a.height + b.width * b.height - overlap)
    }

    private static func round1(_ value: CGFloat) -> Double {
        (Double(value) * 10).rounded() / 10
    }

    private static func weightedPick(_ items: [(String, Double)], using rng: inout TestRNG) -> String {
        let total = items.reduce(0) { $0 + $1.1 }
        var roll = Double.random(in: 0..<total, using: &rng)
        for (item, weight) in items {
            if roll < weight { return item }
            roll -= weight
        }
        return items[items.count - 1].0
    }

    @MainActor
    private static func resizedPNG(_ image: CGImage, width: Int, height: Int) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let size = CGSize(width: width, height: height)
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.pngData { _ in
            UIImage(cgImage: image).draw(in: CGRect(origin: .zero, size: size))
        }
    }

    private static func outputRoot(_ env: [String: String]) -> URL {
        if let path = env["HIGSYNTH_OUTPUT"], !path.isEmpty {
            return URL(fileURLWithPath: (path as NSString).expandingTildeInPath, isDirectory: true)
        }
        // Simulator processes can write straight to the Mac's file system.
        if let hostHome = env["SIMULATOR_HOST_HOME"] {
            return URL(fileURLWithPath: hostHome, isDirectory: true)
                .appendingPathComponent("HIGSynthDataset", isDirectory: true)
        }
        return FileManager.default.temporaryDirectory.appendingPathComponent("HIGSynthDataset", isDirectory: true)
    }
}

/// Same SplitMix64 as the app (UI test bundles can't import the app module).
struct TestRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
