import SwiftUI
import PhotosUI

// MARK: - Screen: pick a screenshot, detect UI elements, check HIG rules

struct DetectorView: View {
    enum Mode: String, CaseIterable { case issues = "HIG Issues", elements = "Elements" }

    @State private var selectedItem: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var detections: [Detection] = []
    @State private var issues: [HIGIssue] = []
    @State private var status = "Choose a screenshot to check it against the HIG."
    @State private var mode: Mode = .issues
    @State private var showLabels = true
    @State private var highlighted: HIGIssue.ID?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if image != nil {
                        Picker("Show", selection: $mode) {
                            ForEach(Mode.allCases, id: \.self) { Text($0.rawValue) }
                        }
                        .pickerStyle(.segmented)
                    }

                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .overlay {
                                GeometryReader { geo in
                                    switch mode {
                                    case .elements:
                                        ForEach(detections) { d in
                                            box(d.box, color: Self.color(for: d.label),
                                                label: "\(d.label) \(Int(d.confidence * 100))%", in: geo.size)
                                        }
                                    case .issues:
                                        ForEach(issues) { issue in
                                            box(issue.box, color: Self.color(for: issue.severity),
                                                label: issue.rule, in: geo.size,
                                                lineWidth: highlighted == issue.id ? 4 : 2)
                                        }
                                    }
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Text(status)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    switch mode {
                    case .issues where image != nil: issueList
                    case .elements where !detections.isEmpty: elementSummary
                    default: EmptyView()
                    }
                }
                .padding()
            }
            .navigationTitle("HIG Check")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Toggle("Labels", systemImage: "tag", isOn: $showLabels)
                }
            }
            .safeAreaInset(edge: .bottom) {
                PhotosPicker("Choose Screenshot", selection: $selectedItem, matching: .screenshots)
                    .buttonStyle(.borderedProminent)
                    .padding()
            }
        }
        .onChange(of: selectedItem) {
            Task { await analyse() }
        }
    }

    // MARK: - Overlay box

    private func box(_ fraction: CGRect, color: Color, label: String, in size: CGSize,
                     lineWidth: CGFloat = 1.5) -> some View {
        let rect = CGRect(x: fraction.minX * size.width, y: fraction.minY * size.height,
                          width: fraction.width * size.width, height: fraction.height * size.height)
        return Rectangle()
            .stroke(color, lineWidth: lineWidth)
            .frame(width: rect.width, height: rect.height)
            .overlay(alignment: .topLeading) {
                if showLabels {
                    Text(label)
                        .font(.system(size: 7, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 2)
                        .background(color)
                        .fixedSize()
                        .offset(y: -9)
                }
            }
            .position(x: rect.midX, y: rect.midY)
    }

    // MARK: - Lists under the image

    private var issueList: some View {
        VStack(alignment: .leading, spacing: 10) {
            if issues.isEmpty {
                Label("No issues found for the rules checked.", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            } else {
                let counts = Dictionary(grouping: issues, by: \.severity).mapValues(\.count)
                HStack(spacing: 16) {
                    ForEach([Severity.problem, .warning, .note], id: \.self) { s in
                        Label("\(counts[s] ?? 0) \(s.title)\(counts[s] == 1 ? "" : "s")",
                              systemImage: Self.icon(for: s))
                            .foregroundStyle(Self.color(for: s))
                    }
                }
                .font(.subheadline.weight(.semibold))

                ForEach(issues) { issue in
                    Button {
                        highlighted = highlighted == issue.id ? nil : issue.id
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: Self.icon(for: issue.severity))
                                .foregroundStyle(Self.color(for: issue.severity))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(issue.severity.title) · \(issue.rule)").font(.subheadline.weight(.semibold))
                                Text(issue.message).font(.footnote).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(10)
                        .background(Color.secondary.opacity(highlighted == issue.id ? 0.3 : 0.12),
                                    in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("Checked: safe areas, tap-target size, text size and text contrast. Tap-target sizes are the visible size of each element; the real tappable area can be larger. Text inside images and photos is not checked.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var elementSummary: some View {
        let counts = Dictionary(grouping: detections, by: \.label).mapValues(\.count)
        return VStack(alignment: .leading, spacing: 6) {
            ForEach(counts.keys.sorted(), id: \.self) { label in
                HStack {
                    Circle().fill(Self.color(for: label)).frame(width: 10, height: 10)
                    Text(label)
                    Spacer()
                    Text("\(counts[label]!)").monospacedDigit().foregroundStyle(.secondary)
                }
                .font(.subheadline)
            }
        }
        .padding()
        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Detection + rules

    private func analyse() async {
        detections = []
        issues = []
        highlighted = nil
        guard let data = try? await selectedItem?.loadTransferable(type: Data.self),
              let picked = UIImage(data: data),
              let cgImage = picked.cgImage
        else {
            status = "Couldn't load that image."
            return
        }
        image = picked
        status = "Checking…"

        // Pixels → points. Recent iPhones are 3×, older/smaller ones 2×.
        let scale: Double = cgImage.width > 1000 ? 3 : 2
        let screenSize = CGSize(width: Double(cgImage.width) / scale, height: Double(cgImage.height) / scale)
        let start = Date()

        do {
            // Run the model off the main thread so the UI stays responsive.
            let found = try await Task.detached(priority: .userInitiated) {
                try ElementDetector.shared.get().detect(in: cgImage, scale: scale)
            }.value

            detections = found

            // Text size + contrast use the Text tab's text recognition and pixel helpers.
            let textObservations = (try? await runVision(on: data)) ?? []
            let textProblems = textIssues(observations: textObservations, cgImage: cgImage,
                                          scale: scale, detections: found)

            issues = HIGRules.sorted(HIGRules.check(found, screenSize: screenSize) + textProblems)
            status = "\(found.count) elements, \(issues.count) issues · \(String(format: "%.2f", Date().timeIntervalSince(start))) s"

            for issue in issues {
                print(issue.severity.title, "|", issue.rule, "|", issue.message)
            }
        } catch DetectorError.modelMissing {
            status = "HIGElementDetector model not found in the app bundle."
        } catch {
            status = "Detection failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Colours and icons

    static func color(for label: String) -> Color {
        switch label {
        case "Text": .yellow
        case "TextButton": .green
        case "Icon": .cyan
        case "Image": .blue
        case "EditText": .orange
        case "Switch": .pink
        case "UpperTaskBar": .purple
        case "PageIndicator": .mint
        case "CheckedTextView": .teal
        default: .gray
        }
    }

    static func color(for severity: Severity) -> Color {
        switch severity {
        case .problem: .red
        case .warning: .orange
        case .note: .blue
        }
    }

    static func icon(for severity: Severity) -> String {
        switch severity {
        case .problem: "xmark.octagon.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .note: "info.circle.fill"
        }
    }
}

#Preview {
    DetectorView()
}
