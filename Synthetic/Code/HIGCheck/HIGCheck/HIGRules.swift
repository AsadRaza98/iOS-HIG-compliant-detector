import Foundation
import CoreGraphics

/// Measurable Human Interface Guidelines checks for the detected elements.
///
/// Measurements come from a screenshot, so they describe what's *visible*. For example,
/// a small visible button can still have a larger tap area in code. Findings are worded
/// with that in mind.
struct HIGRules {
    let elements: [DetectedElement]
    let texts: [TextItem]
    let sampler: PixelSampler?
    let pointScale: CGFloat
    let screenSize: CGSize   // pixels

    // Thresholds (points unless noted)
    static let minimumTapTarget: CGFloat = 44
    static let minimumRowHeight: CGFloat = 44
    static let minimumButtonGap: CGFloat = 8
    static let marginTolerance: CGFloat = 6
    static let maxTrailingGapForSwitch: CGFloat = 32
    static let maxTabBarDistanceFromBottom: CGFloat = 40
    static let maximumTabs = 5

    func evaluate() -> [Finding] {
        let buttons = elements.filter { $0.kind == .button }
        let rows = elements.filter { $0.kind == .listRow }
        let toggles = elements.filter { $0.kind == .toggle }
        let tabBars = elements.filter { $0.kind == .tabBar }

        var findings: [Finding] = []
        for button in buttons { findings += checkButton(button) }
        findings += checkButtonSpacing(buttons)
        for row in rows { findings += checkRow(row) }
        for toggle in toggles { findings += checkToggle(toggle, rows: rows) }
        for tabBar in tabBars { findings += checkTabBar(tabBar) }
        return findings
    }

    // MARK: - Buttons

    private func checkButton(_ button: DetectedElement) -> [Finding] {
        var out: [Finding] = []
        let width = pt(button.rect.width), height = pt(button.rect.height)

        if width < Self.minimumTapTarget || height < Self.minimumTapTarget {
            out.append(make(button, .warning, "Small tap target",
                            "The visible button is smaller than 44 × 44 pt. Make sure its tappable area is at least 44 × 44 pt so people can hit it reliably.",
                            sizeText(button.rect), .buttons))
        } else {
            out.append(make(button, .pass, "Tap target size", "At least 44 × 44 pt.", sizeText(button.rect), .buttons))
        }

        // Shrink slightly so rounded corners and the surrounding background don't skew the result.
        let inner = button.rect.insetBy(dx: button.rect.width * 0.08, dy: button.rect.height * 0.12)
        if let sample = sampler?.contrast(in: inner) {
            let ratio = String(format: "%.1f:1 contrast", sample.ratio)
            if sample.ratio < 3 {
                out.append(make(button, .fail, "Low label contrast",
                                "The label and its background have a contrast ratio below 3:1, which is hard to read for many people. Aim for at least 4.5:1.",
                                ratio, .accessibility))
            } else if sample.ratio < 4.5 {
                out.append(make(button, .warning, "Label contrast could be higher",
                                "The contrast ratio is between 3:1 and 4.5:1. That's only enough for large or bold text; aim for 4.5:1.",
                                ratio, .accessibility))
            } else {
                out.append(make(button, .pass, "Label contrast", "At least 4.5:1.", ratio, .accessibility))
            }
        }
        return out
    }

    private func checkButtonSpacing(_ buttons: [DetectedElement]) -> [Finding] {
        var out: [Finding] = []
        for i in buttons.indices {
            for j in buttons.indices where j > i {
                let a = buttons[i].rect, b = buttons[j].rect
                if a.intersects(b) { continue }
                let dx = max(0, max(a.minX - b.maxX, b.minX - a.maxX))
                let dy = max(0, max(a.minY - b.maxY, b.minY - a.maxY))
                // Only compare buttons that sit side by side or directly above each other.
                let gap: CGFloat
                if dy == 0 { gap = dx } else if dx == 0 { gap = dy } else { continue }
                if pt(gap) < Self.minimumButtonGap {
                    out.append(make(buttons[i], .warning, "Buttons are close together",
                                    "\(buttons[i].name) and \(buttons[j].name) are only \(Int(pt(gap).rounded())) pt apart. Leave more space between buttons so people don't tap the wrong one.",
                                    String(format: "%.0f pt gap", pt(gap)), .buttons))
                }
            }
        }
        return out
    }

    // MARK: - List rows

    private func checkRow(_ row: DetectedElement) -> [Finding] {
        var out: [Finding] = []
        let height = pt(row.rect.height)
        if height < Self.minimumRowHeight {
            out.append(make(row, .fail, "Row is too short",
                            "List rows should be at least 44 pt tall so they're easy to tap.",
                            String(format: "%.0f pt tall", height), .lists))
        } else {
            out.append(make(row, .pass, "Row height", "At least 44 pt tall.", String(format: "%.0f pt tall", height), .lists))
        }

        let leading = pt(row.rect.minX)
        let trailing = pt(screenSize.width - row.rect.maxX)
        let margins = String(format: "%.0f pt / %.0f pt margins", leading, trailing)
        if abs(leading - trailing) > Self.marginTolerance {
            out.append(make(row, .warning, "Uneven side margins",
                            "The row's leading and trailing margins differ. Rows normally use the same margin on both sides so content lines up.",
                            margins, .layout))
        } else {
            out.append(make(row, .pass, "Side margins", "Leading and trailing margins match.", margins, .layout))
        }
        return out
    }

    // MARK: - Switches

    private func checkToggle(_ toggle: DetectedElement, rows: [DetectedElement]) -> [Finding] {
        var out: [Finding] = []
        let width = pt(toggle.rect.width), height = pt(toggle.rect.height)

        if height < 24 || height > 40 || width < 40 || width > 72 {
            out.append(make(toggle, .warning, "Non-standard switch size",
                            "This switch doesn't match the system size. Use the standard switch instead of scaling or redrawing it, so it looks and behaves as people expect.",
                            sizeText(toggle.rect), .toggles))
        } else {
            out.append(make(toggle, .pass, "Standard switch size", "Matches the system switch.", sizeText(toggle.rect), .toggles))
        }

        let center = CGPoint(x: toggle.rect.midX, y: toggle.rect.midY)
        if let row = rows.first(where: { $0.rect.contains(center) }) {
            let trailingGap = pt(row.rect.maxX - toggle.rect.maxX)
            let measured = String(format: "%.0f pt from row edge", trailingGap)
            if trailingGap > Self.maxTrailingGapForSwitch {
                out.append(make(toggle, .warning, "Switch isn't at the trailing edge",
                                "In a list row, place the switch at the trailing edge so it lines up with the switches and accessories in other rows.",
                                measured, .toggles))
            } else {
                out.append(make(toggle, .pass, "Trailing alignment", "Sits at the row's trailing edge.", measured, .toggles))
            }
        }

        // Look for text to the left of the switch, roughly on the same line.
        let band = toggle.rect.insetBy(dx: 0, dy: -toggle.rect.height * 0.6)
        let hasLabel = texts.contains { text in
            text.rect.maxX <= toggle.rect.minX + 4
                && text.rect.midY >= band.minY && text.rect.midY <= band.maxY
                && text.string.trimmingCharacters(in: .whitespaces).count > 1
        }
        if hasLabel {
            out.append(make(toggle, .pass, "Has a label", "Text next to the switch says what it controls.", nil, .toggles))
        } else {
            out.append(make(toggle, .warning, "No visible label",
                            "A switch needs a label next to it that says what it turns on or off.",
                            nil, .toggles))
        }
        return out
    }

    // MARK: - Tab bar

    private func checkTabBar(_ tabBar: DetectedElement) -> [Finding] {
        var out: [Finding] = []

        let distance = pt(screenSize.height - tabBar.rect.maxY)
        if distance > Self.maxTabBarDistanceFromBottom {
            out.append(make(tabBar, .fail, "Tab bar isn't at the bottom",
                            "On iPhone, the tab bar belongs at the bottom of the screen, where people expect to switch between sections.",
                            String(format: "%.0f pt above the bottom", distance), .tabBars))
        } else {
            out.append(make(tabBar, .pass, "Position", "At the bottom of the screen.", nil, .tabBars))
        }

        // Tab titles found by text recognition. Ignore small numeric badges like "6".
        let titles = texts.filter { text in
            tabBar.rect.contains(CGPoint(x: text.rect.midX, y: text.rect.midY)) && !isBadge(text.string)
        }
        let count = titles.count
        if count > Self.maximumTabs {
            out.append(make(tabBar, .fail, "Too many tabs",
                            "Use no more than five tabs on iPhone. With more, iOS moves the rest into a More tab, which hides those sections.",
                            "\(count) tabs", .tabBars))
        } else if count == 0 {
            out.append(make(tabBar, .info, "No tab titles found",
                            "Tabs usually pair an icon with a short title, which helps people recognize each section quickly.",
                            nil, .tabBars))
        } else {
            out.append(make(tabBar, .pass, "Number of tabs", "No more than five tabs.", "\(count) tabs", .tabBars))
        }
        return out
    }

    // MARK: - Helpers

    private func pt(_ pixels: CGFloat) -> CGFloat { pixels / pointScale }

    private func sizeText(_ rect: CGRect) -> String {
        String(format: "%.0f × %.0f pt", pt(rect.width), pt(rect.height))
    }

    private func isBadge(_ string: String) -> Bool {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty && trimmed.count <= 3 && trimmed.allSatisfy(\.isNumber)
    }

    private func make(_ element: DetectedElement, _ severity: Severity, _ title: String, _ detail: String,
                      _ measurement: String?, _ guideline: Guideline) -> Finding {
        Finding(elementID: element.id, elementName: element.name, kind: element.kind, severity: severity,
                title: title, detail: detail, measurement: measurement, guideline: guideline)
    }
}
