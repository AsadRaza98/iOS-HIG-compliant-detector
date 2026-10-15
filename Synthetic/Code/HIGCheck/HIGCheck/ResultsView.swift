import SwiftUI

struct ResultsView: View {
    let result: AnalysisResult

    @State private var filter: ElementKind?
    @State private var selectedElement: DetectedElement?
    @State private var showsPassed = false

    private var visibleFindings: [Finding] {
        result.findings.filter { filter == nil || $0.kind == filter }
    }

    private var issues: [Finding] {
        visibleFindings.filter { $0.severity != .pass }.sorted { $0.severity > $1.severity }
    }

    private var passed: [Finding] {
        visibleFindings.filter { $0.severity == .pass }
    }

    var body: some View {
        List {
            Section {
                SummaryView(result: result)
            }

            Section {
                AnnotatedScreenshot(result: result, filter: filter) { selectedElement = $0 }
                    .frame(maxWidth: .infinity)
                    .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
            } footer: {
                Text("Tap a box to see its checks. Only elements detected with at least 60% confidence are shown.")
            }

            Section {
                Picker("Show", selection: $filter) {
                    Text("All").tag(ElementKind?.none)
                    ForEach(ElementKind.allCases) { kind in
                        Text(kind.plural).tag(ElementKind?.some(kind))
                    }
                }
                .pickerStyle(.segmented)
            }

            Section(issues.isEmpty ? "No Issues" : "Issues") {
                if issues.isEmpty {
                    Label("Every check here follows the guidelines.", systemImage: "checkmark.circle")
                        .foregroundStyle(.secondary)
                }
                ForEach(issues) { finding in
                    FindingRow(finding: finding)
                }
            }

            if !passed.isEmpty {
                Section {
                    DisclosureGroup("Passed Checks (\(passed.count))", isExpanded: $showsPassed) {
                        ForEach(passed) { finding in
                            FindingRow(finding: finding)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .sheet(item: $selectedElement) { element in
            ElementDetailView(element: element, findings: result.findings.filter { $0.elementID == element.id })
                .presentationDetents([.medium, .large])
        }
    }
}

// MARK: - Summary

struct SummaryView: View {
    let result: AnalysisResult

    private var headline: String {
        if result.elements.isEmpty { return "No supported elements found" }
        if result.count(.fail) > 0 { return "Needs work" }
        if result.count(.warning) > 0 { return "Mostly good" }
        return "Looks great"
    }

    private var breakdown: String {
        let parts = ElementKind.allCases.compactMap { kind -> String? in
            let count = result.elements.filter { $0.kind == kind }.count
            return count == 0 ? nil : "\(count) \(count == 1 ? kind.singular.lowercased() : kind.plural.lowercased())"
        }
        return parts.isEmpty
            ? "Try a screenshot with buttons, list rows, switches or a tab bar."
            : "Found " + parts.joined(separator: ", ") + "."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(headline)
                .font(.title3.bold())
            HStack {
                StatView(value: result.count(.fail), label: "Failed", severity: .fail)
                StatView(value: result.count(.warning), label: "Warnings", severity: .warning)
                StatView(value: result.count(.pass), label: "Passed", severity: .pass)
            }
            Text(breakdown)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct StatView: View {
    let value: Int
    let label: String
    let severity: Severity

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.title.bold())
                .foregroundStyle(value == 0 ? Color.secondary : severity.color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Screenshot with boxes

struct AnnotatedScreenshot: View {
    let result: AnalysisResult
    let filter: ElementKind?
    let onSelect: (DetectedElement) -> Void

    var body: some View {
        Image(uiImage: result.image)
            .resizable()
            .scaledToFit()
            .frame(maxHeight: 520)
            .overlay {
                GeometryReader { geometry in
                    let k = geometry.size.width / result.pixelSize.width
                    ForEach(result.elements.filter { filter == nil || $0.kind == filter }) { element in
                        let rect = CGRect(x: element.rect.minX * k, y: element.rect.minY * k,
                                          width: element.rect.width * k, height: element.rect.height * k)
                        let severity = result.worstSeverity(for: element.id)
                        ZStack {
                            // Tap area is at least 44 × 44 pt, even for small elements.
                            Color.clear
                                .frame(width: max(rect.width, 44), height: max(rect.height, 44))
                                .contentShape(Rectangle())
                            Rectangle()
                                .strokeBorder(severity.color, lineWidth: 2)
                                .background(severity.color.opacity(0.1))
                                .frame(width: rect.width, height: rect.height)
                        }
                        .position(x: rect.midX, y: rect.midY)
                        .onTapGesture { onSelect(element) }
                        .accessibilityElement()
                        .accessibilityLabel("\(element.name), \(severity.label)")
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { onSelect(element) }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Screenshot with detected elements")
    }
}

// MARK: - Findings

struct FindingRow: View {
    let finding: Finding

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: finding.severity.symbol)
                .foregroundStyle(finding.severity.color)
                .accessibilityLabel(finding.severity.label)
            VStack(alignment: .leading, spacing: 4) {
                Text(finding.title)
                    .font(.headline)
                Text([finding.elementName, finding.measurement].compactMap { $0 }.joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if finding.severity != .pass {
                    Text(finding.detail)
                        .font(.subheadline)
                }
                Link("HIG: \(finding.guideline.title)", destination: finding.guideline.url)
                    .font(.footnote)
            }
        }
        .padding(.vertical, 2)
    }
}

struct ElementDetailView: View {
    let element: DetectedElement
    let findings: [Finding]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Type", value: element.kind.singular)
                    LabeledContent("Detection confidence",
                                   value: Double(element.confidence).formatted(.percent.precision(.fractionLength(0))))
                }
                Section("Checks") {
                    if findings.isEmpty {
                        Text("No checks apply to this element.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(findings.sorted { $0.severity > $1.severity }) { finding in
                        FindingRow(finding: finding)
                    }
                }
            }
            .navigationTitle(element.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
