import CoreGraphics
import Foundation
// MARK: - HIG rule checks on detected UI elements
//
// Rules (all sizes in points):
//  1. Safe areas — tappable elements must not sit under the status bar / Dynamic Island
//     or on the home indicator.                                              → Problem
//  2. Tap target size — HIG asks for at least 44 × 44 pt.
//     We only see the *visible* size; the real tappable area can be larger
//     (Apple's own 32 pt "Get" buttons have a bigger hit area). So:
//       • control smaller than 28 pt                                          → Warning
//       • control 28–42 pt                                                    → Note
//       • standalone icon under 44 pt (it might be a button)                  → Note
//  3. Text size and 4. text contrast — see TextRules.swift.
//
// Tuned on 10 real iOS 26 screenshots so Apple's own apps don't raise false alarms:
//  - icons inside another element (e.g. the magnifier in a search field) are skipped,
//  - icons with a text label beside or below them (list rows, tab items) are skipped:
//    the whole row/item is the tap target,
//  - tiny icons (< 12 pt, e.g. list chevrons) are treated as decoration,
//  - content clipped at the screen edge (scrolled content) is ignored for safe areas.

nonisolated enum Severity: Int, Comparable, Sendable {
    case note = 0, warning = 1, problem = 2
    static func < (a: Severity, b: Severity) -> Bool { a.rawValue < b.rawValue }

    var title: String {
        switch self {
        case .problem: "Problem"
        case .warning: "Warning"
        case .note: "Note"
        }
    }
}

nonisolated struct HIGIssue: Identifiable, Sendable {
    let id = UUID()
    let severity: Severity
    let rule: String     // short rule name, e.g. "Tap target"
    let message: String  // explanation for this element
    let box: CGRect      // where it is: fractions 0–1 of the screenshot, top-left origin
    let rectPt: CGRect   // the same in points

    init(severity: Severity, rule: String, message: String, box: CGRect, rectPt: CGRect) {
        self.severity = severity; self.rule = rule; self.message = message
        self.box = box; self.rectPt = rectPt
    }

    init(severity: Severity, rule: String, message: String, detection: Detection) {
        self.init(severity: severity, rule: rule, message: message, box: detection.box, rectPt: detection.rectPt)
    }
}

nonisolated enum HIGRules {
    static let minTapTarget = 44.0   // HIG minimum, pt
    static let tinyControl = 28.0    // below this a control is almost certainly too small
    static let tolerance = 2.0       // detector boxes are accurate to roughly ±2 pt
    static let homeIndicatorBand = 20.0
    static let minIconSize = 12.0    // smaller icons are treated as decoration (chevrons etc.)
    static let minIconConfidence: Float = 0.5
    static let minTextSize = 11.0    // HIG: smallest recommended text size on iOS, pt

    static let controls: Set<String> = ["TextButton", "EditText", "CheckedTextView"]

    /// Top safe-area inset for a screen height in points.
    static func topInset(screenHeight h: Double) -> Double {
        if h >= 852 { return 59 }   // Dynamic Island iPhones
        if h >= 812 { return 47 }   // notch iPhones
        return 20                   // home-button iPhones
    }

    static func check(_ detections: [Detection], screenSize: CGSize) -> [HIGIssue] {
        let H = screenSize.height
        let top = topInset(screenHeight: H)
        let hasHomeIndicator = H >= 812
        let statusBars = detections.filter { $0.label == "UpperTaskBar" }

        var issues: [HIGIssue] = []

        for d in detections {
            let r = d.rectPt
            if d.label == "UpperTaskBar" || statusBars.contains(where: { contains($0.rectPt, r, pad: 4) }) { continue }
            if min(r.width, r.height) < 6 { continue }   // slivers

            guard isTappable(d, among: detections) else { continue }

            // Rule 1: safe areas
            let clippedAtEdge = r.minY <= 1 || r.maxY >= H - 1
            if !clippedAtEdge {
                if r.minY < top - tolerance {
                    issues.append(HIGIssue(
                        severity: .problem, rule: "Safe area",
                        message: "\(d.label) sits under the status bar / Dynamic Island (top \(Int(top)) pt). Move it below the top safe area.",
                        detection: d))
                }
                if hasHomeIndicator && r.maxY > H - homeIndicatorBand {
                    issues.append(HIGIssue(
                        severity: .problem, rule: "Safe area",
                        message: "\(d.label) overlaps the home indicator. Keep controls above the bottom safe area.",
                        detection: d))
                }
            }

            // Rule 2: tap target size (switches are system controls with a built-in hit area)
            guard d.label != "Switch" else { continue }
            let smallest = min(r.width, r.height)
            let size = "\(Int(r.width.rounded()))×\(Int(r.height.rounded())) pt"

            if d.label == "Icon" {
                if d.confidence >= minIconConfidence && smallest < minTapTarget - tolerance {
                    issues.append(HIGIssue(
                        severity: .note, rule: "Tap target",
                        message: "Icon is \(size). If it's tappable, make its hit area at least 44×44 pt.",
                        detection: d))
                }
            } else if smallest < tinyControl {
                issues.append(HIGIssue(
                    severity: .warning, rule: "Tap target",
                    message: "\(d.label) is only \(size) — well below the 44×44 pt minimum.",
                    detection: d))
            } else if smallest < minTapTarget - tolerance {
                issues.append(HIGIssue(
                    severity: .note, rule: "Tap target",
                    message: "\(d.label) looks \(size). Make sure its tappable area is at least 44×44 pt.",
                    detection: d))
            }
        }

        return sorted(issues)
    }

    /// Most severe first, then top to bottom.
    static func sorted(_ issues: [HIGIssue]) -> [HIGIssue] {
        issues.sorted {
            ($0.severity.rawValue, -$0.rectPt.minY) > ($1.severity.rawValue, -$1.rectPt.minY)
        }
    }

    // Controls and switches are tappable. Icons count only when they stand alone:
    // not inside another element, not labelled by nearby text, and not tiny.
    static func isTappable(_ d: Detection, among all: [Detection]) -> Bool {
        if controls.contains(d.label) || d.label == "Switch" { return true }
        guard d.label == "Icon" else { return false }
        let r = d.rectPt
        if min(r.width, r.height) < minIconSize { return false }
        if all.contains(where: { $0.id != d.id && $0.label != "Text" && contains($0.rectPt, r, pad: 2) }) { return false }
        return !hasLabel(r, among: all)
    }

    // Text right beside the icon (list row) or just below it (tab item).
    static func hasLabel(_ icon: CGRect, among all: [Detection]) -> Bool {
        all.contains { t in
            guard t.label == "Text" else { return false }
            let tr = t.rectPt
            let sameRow = abs(tr.midY - icon.midY) < max(icon.height, tr.height)
                && (0..<24).contains(tr.minX - icon.maxX)
            let below = (0..<12).contains(tr.minY - icon.maxY)
                && tr.minX < icon.midX && icon.midX < tr.maxX
            return sameRow || below
        }
    }

    static func contains(_ outer: CGRect, _ inner: CGRect, pad: Double) -> Bool {
        outer.insetBy(dx: -pad, dy: -pad).contains(inner)
    }
}
