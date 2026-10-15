import SwiftUI
import PhotosUI
import Vision

// MARK: - Data for each detected piece of text

struct TextItem: Identifiable {
    let id = UUID()
    let text: String
    let box: CGRect      // fractions 0–1, top-left origin
    let sizePt: Double   // estimated font size in points
    let group: String    // size group (Level 2)
    let role: String     // guessed role (Level 1)
    let contrast: Double? // text vs background, e.g. 4.5 means 4.5:1
}

// Vision's box height ÷ real font size. 1.0 is a placeholder:
// measure it with CalibrationView (bottom of this file).
let boxToFontRatio = 1.0

// MARK: - Level 2: put a size into a group
// Size is only accurate to about ±18%, so we use four groups instead of
// ten exact styles. Boundaries sit halfway between groups; tune them
// with your calibration numbers.

func sizeGroup(for size: Double) -> String {
    switch size {
    case ..<14.5: return "Small"        // Footnote 13, Caption 1 12, Caption 2 11
    case ..<18.5: return "Body"         // Body 17, Callout 16, Subheadline 15
    case ..<31:   return "Title"        // Title 1 28, Title 2 22, Title 3 20
    default:      return "Large title"  // Large Title 34
    }
}

// MARK: - Level 1: guess the role from size group and position

func guessRole(group: String, yPt: Double, screenHeightPt: Double) -> String {
    if yPt < 50 { return "Status bar" }
    if yPt > screenHeightPt - 90 && group == "Small" { return "Tab label" }
    if group == "Title" || group == "Large title" { return "Title" }
    if group == "Small" { return "Header/caption" }
    return "Body"
}

// MARK: - Screen

struct ContentView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var items: [TextItem] = []

    var body: some View {
        VStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .overlay {
                        GeometryReader { geo in
                            ForEach(items) { item in
                                let color: Color = item.passesContrast == false ? .red : .green
                                Rectangle()
                                    .stroke(color, lineWidth: 1)
                                    .frame(width: item.box.width * geo.size.width,
                                           height: item.box.height * geo.size.height)
                                    .overlay(alignment: .topLeading) {
                                        Text("\(item.role) \(Int(item.sizePt.rounded()))pt \(contrastLabel(item))")
                                            .font(.system(size: 7))
                                            .foregroundStyle(.white)
                                            .background(color)
                                            .fixedSize()
                                            .offset(y: -9)
                                    }
                                    .offset(x: item.box.minX * geo.size.width,
                                            y: item.box.minY * geo.size.height)
                            }
                        }
                    }
            }

            PhotosPicker("Choose Screenshot", selection: $selectedItem, matching: .images)
        }
        .onChange(of: selectedItem) {
            Task {
                items = []
                guard let data = try? await selectedItem?.loadTransferable(type: Data.self),
                      let picked = UIImage(data: data),
                      let cgImage = picked.cgImage else { return }
                image = picked

                // Pixels → points. Recent iPhones are 3×, older/smaller ones 2×.
                let pixelWidth = Double(cgImage.width)
                let pixelHeight = Double(cgImage.height)
                let scale: Double = pixelWidth > 1000 ? 3 : 2
                let screenHeightPt = pixelHeight / scale

                guard let observations = try? await runVision(on: data) else { return }
                let pixels = PixelReader(cgImage: cgImage)

                items = observations.compactMap { observation in
                    guard let text = observation.topCandidates(1).first?.string else { return nil }
                    let box = observation.boundingBox.toImageCoordinates(
                        CGSize(width: 1, height: 1), origin: .upperLeft)

                    let boxHeightPt = box.height * pixelHeight / scale
                    let sizePt = boxHeightPt / boxToFontRatio
                    let group = sizeGroup(for: sizePt)
                    let role = guessRole(group: group,
                                         yPt: box.minY * screenHeightPt,
                                         screenHeightPt: screenHeightPt)

                    let contrast = pixels.flatMap { contrastRatio(in: box, pixels: $0) }

                    return TextItem(text: text, box: box, sizePt: sizePt, group: group,
                                    role: role, contrast: contrast)
                }

                for item in items {
                    print(item.role, "|", item.group, "|",
                          String(format: "%.1f pt", item.sizePt), "|",
                          contrastLabel(item), "|", item.text)
                }
            }
        }
    }
}

func contrastLabel(_ item: TextItem) -> String {
    guard let contrast = item.contrast else { return "?" }
    return String(format: "%.1f:1", contrast)
}

func runVision(on data: Data) async throws -> [RecognizedTextObservation] {
    var request = RecognizeTextRequest()
    request.usesLanguageCorrection = false
    return try await request.perform(on: data)
}

// MARK: - Calibration screen (temporary)
// Show this instead of ContentView, take a screenshot, then run the checker on it.

struct CalibrationView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Large Title 34").font(.largeTitle)
            Text("Title 1 28").font(.title)
            Text("Title 2 22").font(.title2)
            Text("Title 3 20").font(.title3)
            Text("Body 17").font(.body)
            Text("Callout 16").font(.callout)
            Text("Subheadline 15").font(.subheadline)
            Text("Footnote 13").font(.footnote)
            Text("Caption 1 12").font(.caption)
            Text("Caption 2 11").font(.caption2)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
