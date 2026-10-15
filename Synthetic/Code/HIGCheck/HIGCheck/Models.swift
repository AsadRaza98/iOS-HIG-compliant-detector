import SwiftUI

/// The element types this app checks. These are the classes the detector handles
/// reliably on real screenshots; other detections are ignored.
enum ElementKind: String, CaseIterable, Identifiable {
    case button, listRow, toggle, tabBar

    var id: String { rawValue }

    /// Name used on screen (iOS calls toggles "switches").
    var singular: String {
        switch self {
        case .button: return "Button"
        case .listRow: return "Row"
        case .toggle: return "Switch"
        case .tabBar: return "Tab Bar"
        }
    }

    var plural: String {
        switch self {
        case .button: return "Buttons"
        case .listRow: return "Rows"
        case .toggle: return "Switches"
        case .tabBar: return "Tab Bar"
        }
    }
}

enum Severity: Int, Comparable {
    case pass = 0, info = 1, warning = 2, fail = 3

    static func < (lhs: Severity, rhs: Severity) -> Bool { lhs.rawValue < rhs.rawValue }

    var label: String {
        switch self {
        case .pass: return "Passed"
        case .info: return "Note"
        case .warning: return "Warning"
        case .fail: return "Failed"
        }
    }

    var symbol: String {
        switch self {
        case .pass: return "checkmark.circle.fill"
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .fail: return "xmark.octagon.fill"
        }
    }

    var color: Color {
        switch self {
        case .pass: return .green
        case .info: return .blue
        case .warning: return .orange
        case .fail: return .red
        }
    }
}

struct DetectedElement: Identifiable {
    let id = UUID()
    let kind: ElementKind
    /// Bounding box in image pixels, top-left origin.
    let rect: CGRect
    let confidence: Float
    /// 1-based number within its kind, in reading order (top to bottom).
    var index = 0

    var name: String { kind == .tabBar ? kind.singular : "\(kind.singular) \(index)" }
}

/// Text found by on-device text recognition, in image pixels (top-left origin).
struct TextItem {
    let string: String
    let rect: CGRect
}

struct Guideline {
    let title: String
    let url: URL

    private static func hig(_ title: String, _ path: String) -> Guideline {
        Guideline(title: title, url: URL(string: "https://developer.apple.com/design/human-interface-guidelines/\(path)")!)
    }

    static let buttons = hig("Buttons", "buttons")
    static let toggles = hig("Toggles", "toggles")
    static let lists = hig("Lists and tables", "lists-and-tables")
    static let tabBars = hig("Tab bars", "tab-bars")
    static let accessibility = hig("Accessibility", "accessibility")
    static let layout = hig("Layout", "layout")
}

struct Finding: Identifiable {
    let id = UUID()
    let elementID: UUID?
    let elementName: String
    let kind: ElementKind
    let severity: Severity
    let title: String
    let detail: String
    let measurement: String?
    let guideline: Guideline
}

struct AnalysisResult {
    let image: UIImage
    let pixelSize: CGSize
    /// Screen scale used to convert pixels to points (2 or 3).
    let pointScale: CGFloat
    let elements: [DetectedElement]
    let findings: [Finding]

    func worstSeverity(for elementID: UUID) -> Severity {
        findings.filter { $0.elementID == elementID }.map(\.severity).max() ?? .pass
    }

    func count(_ severity: Severity) -> Int {
        findings.filter { $0.severity == severity }.count
    }
}
