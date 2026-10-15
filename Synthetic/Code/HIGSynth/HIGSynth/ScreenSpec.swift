import SwiftUI

// A ScreenSpec is a plain description of a screen. The generator builds one from a seed,
// and the views in SynthViews.swift render it with native SwiftUI components.

enum Archetype {
    case settingsForm   // grouped Form/List with toggles, value rows, disclosure rows
    case plainList      // content list: icon + title + subtitle rows
    case scrollContent  // ScrollView with buttons, fields, cards, segmented controls
    case authForm       // sign-in / sign-up style screen
}

enum ListStyleKind {
    case insetGrouped, grouped, plain
}

enum ButtonStyleKind {
    case prominent, bordered, borderless, custom
}

enum ButtonSizeKind {
    case small, regular, large, extraLarge

    var controlSize: ControlSize {
        switch self {
        case .small: return .small
        case .regular: return .regular
        case .large: return .large
        case .extraLarge: return .extraLarge
        }
    }

    /// Vertical padding for the hand-styled "custom" buttons, which mimic real-world app styling.
    var customVerticalPadding: CGFloat {
        switch self {
        case .small: return 6
        case .regular: return 10
        case .large: return 14
        case .extraLarge: return 18
        }
    }
}

enum FieldStyleKind {
    case rounded, underlined, filled
}

struct ButtonSpec {
    let id: String
    let title: String
    let symbol: String?
    let iconOnly: Bool
    let style: ButtonStyleKind
    let size: ButtonSizeKind
    let fullWidth: Bool
    let capsule: Bool
    let colorIndex: Int
    let cornerRadius: CGFloat
}

struct FieldSpec {
    let placeholder: String
    let secure: Bool
    let style: FieldStyleKind
    let prefilled: String?
}

struct SegmentSpec {
    let options: [String]
    let selected: Int
}

enum RowSpec {
    case toggle(title: String, symbol: String?, colorIndex: Int, isOn: Bool)
    case navigation(title: String, symbol: String?, colorIndex: Int, detail: String?)
    case value(title: String, detail: String)
    case textField(FieldSpec)
    case segmented(SegmentSpec)
    case subtitle(title: String, subtitle: String, symbol: String, colorIndex: Int, trailing: String?)
}

struct SectionSpec {
    let header: String?
    let footer: String?
    let rows: [RowSpec]
}

enum BlockSpec {
    case heading(String, large: Bool)
    case paragraph(String)
    case button(ButtonSpec)
    case buttonRow([ButtonSpec])
    case textField(FieldSpec)
    case toggleCard(title: String, subtitle: String?, isOn: Bool)
    case segmented(SegmentSpec)
    case image(height: CGFloat, colorIndex: Int, symbol: String)
    case iconLabel(symbol: String, text: String)
    case progress(Double)
    case divider
}

struct TabSpec {
    let title: String
    let symbol: String
}

struct ScreenSpec {
    let seed: UInt64
    let archetype: Archetype
    let title: String
    let showsNavBar: Bool
    let largeTitle: Bool
    let searchable: Bool
    let searchPrompt: String
    let tabs: [TabSpec]
    let selectedTab: Int
    let dark: Bool
    let tintIndex: Int
    let listStyle: ListStyleKind
    let sections: [SectionSpec]
    let blocks: [BlockSpec]
    let bottomButton: ButtonSpec?
    let spacing: CGFloat
    let horizontalPadding: CGFloat
    let groupedBackground: Bool
}

enum Palette {
    static let colors: [Color] = [
        .blue, .indigo, .purple, .pink, .red, .orange, .yellow,
        .green, .mint, .teal, .cyan, .brown,
        Color(red: 0.11, green: 0.11, blue: 0.13),
        Color(red: 0.95, green: 0.36, blue: 0.22),
        Color(red: 0.20, green: 0.55, blue: 0.45),
    ]

    static var count: Int { colors.count }
}
