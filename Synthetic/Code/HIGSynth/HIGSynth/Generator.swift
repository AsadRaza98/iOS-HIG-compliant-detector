import SwiftUI

extension ScreenSpec {
    static func generate(seed: UInt64) -> ScreenSpec {
        let g = Gen(seed: seed)

        let archetype = g.weighted([
            (Archetype.settingsForm, 0.30),
            (Archetype.plainList, 0.25),
            (Archetype.scrollContent, 0.30),
            (Archetype.authForm, 0.15),
        ])

        let showsNavBar = archetype == .authForm ? g.chance(0.25) : g.chance(0.92)

        let searchChance: Double
        switch archetype {
        case .plainList: searchChance = 0.5
        case .authForm: searchChance = 0
        case .settingsForm, .scrollContent: searchChance = 0.15
        }
        let searchable = showsNavBar && g.chance(searchChance)

        let wantsTabs = g.chance(archetype == .authForm ? 0.1 : 0.55)
        let tabs: [TabSpec] = wantsTabs
            ? g.sample(Words.tabs, count: g.int(2...5)).map { TabSpec(title: $0.title, symbol: $0.symbol) }
            : []
        let selectedTab = tabs.isEmpty ? 0 : g.int(0...(tabs.count - 1))
        let title = (tabs.isEmpty || g.chance(0.4)) ? g.pick(Words.screenTitles) : tabs[selectedTab].title

        let listStyle: ListStyleKind
        if archetype == .plainList {
            listStyle = g.chance(0.6) ? .plain : .insetGrouped
        } else {
            listStyle = g.chance(0.75) ? .insetGrouped : .grouped
        }

        var sections: [SectionSpec] = []
        var blocks: [BlockSpec] = []
        switch archetype {
        case .settingsForm:
            sections = (0..<g.int(1...4)).map { _ in settingsSection(g) }
        case .plainList:
            sections = (0..<g.int(1...2)).map { _ in listSection(g) }
        case .scrollContent:
            blocks = scrollBlocks(g)
        case .authForm:
            blocks = authBlocks(g)
        }

        let bottomChance: Double
        switch archetype {
        case .scrollContent: bottomChance = 0.2
        case .authForm: bottomChance = 0
        case .settingsForm, .plainList: bottomChance = 0.15
        }
        var bottomButton: ButtonSpec? = nil
        if g.chance(bottomChance) {
            let style: ButtonStyleKind = g.chance(0.7) ? .prominent : .custom
            bottomButton = makeButton(g, fullWidth: true, allowIconOnly: false, preferredStyle: style,
                                      id: "synth.button.bottom")
        }

        return ScreenSpec(
            seed: seed,
            archetype: archetype,
            title: title,
            showsNavBar: showsNavBar,
            largeTitle: g.chance(0.6),
            searchable: searchable,
            searchPrompt: g.pick(Words.searchPrompts),
            tabs: tabs,
            selectedTab: selectedTab,
            dark: g.chance(0.45),
            tintIndex: g.int(0...(Palette.count - 1)),
            listStyle: listStyle,
            sections: sections,
            blocks: blocks,
            bottomButton: bottomButton,
            spacing: g.pick([12, 16, 20, 24] as [CGFloat]),
            horizontalPadding: g.pick([16, 20, 24] as [CGFloat]),
            groupedBackground: g.chance(0.3)
        )
    }

    // MARK: - Building blocks

    static func makeButton(
        _ g: Gen,
        fullWidth: Bool? = nil,
        allowIconOnly: Bool = true,
        preferredStyle: ButtonStyleKind? = nil,
        title: String? = nil,
        symbol: String? = nil,
        id: String? = nil
    ) -> ButtonSpec {
        let style = preferredStyle ?? g.weighted([
            (ButtonStyleKind.prominent, 0.35),
            (ButtonStyleKind.bordered, 0.25),
            (ButtonStyleKind.borderless, 0.20),
            (ButtonStyleKind.custom, 0.20),
        ])
        let canBeIconOnly = allowIconOnly && (style == .borderless || style == .bordered)
        let iconOnly = canBeIconOnly && g.chance(0.25)
        let chosenSymbol: String? = symbol ?? ((iconOnly || g.chance(0.3)) ? g.pick(Words.symbols) : nil)
        let isFullWidth = fullWidth ?? (style != .borderless && g.chance(0.45))
        let size = g.weighted([
            (ButtonSizeKind.small, 0.15),
            (ButtonSizeKind.regular, 0.35),
            (ButtonSizeKind.large, 0.40),
            (ButtonSizeKind.extraLarge, 0.10),
        ])

        return ButtonSpec(
            id: id ?? g.nextButtonID(),
            title: title ?? g.pick(Words.buttonTitles),
            symbol: chosenSymbol,
            iconOnly: iconOnly && chosenSymbol != nil,
            style: style,
            size: size,
            fullWidth: isFullWidth && !iconOnly,
            capsule: g.chance(0.3),
            colorIndex: g.int(0...(Palette.count - 1)),
            cornerRadius: g.pick([8, 10, 12, 14, 16] as [CGFloat])
        )
    }

    static func makeField(
        _ g: Gen,
        style: FieldStyleKind? = nil,
        secure: Bool? = nil,
        placeholder: String? = nil
    ) -> FieldSpec {
        let isSecure = secure ?? g.chance(0.15)
        let chosenStyle = style ?? g.weighted([
            (FieldStyleKind.rounded, 0.40),
            (FieldStyleKind.underlined, 0.25),
            (FieldStyleKind.filled, 0.35),
        ])
        let prefilled: String? = (!isSecure && g.chance(0.3)) ? g.pick(Words.prefills) : nil
        return FieldSpec(
            placeholder: placeholder ?? (isSecure ? "Password" : g.pick(Words.placeholders)),
            secure: isSecure,
            style: chosenStyle,
            prefilled: prefilled
        )
    }

    static func makeSegment(_ g: Gen) -> SegmentSpec {
        let options = g.pick(Words.segmentSets)
        return SegmentSpec(options: options, selected: g.int(0...(options.count - 1)))
    }

    // MARK: - Archetypes

    static func settingsSection(_ g: Gen) -> SectionSpec {
        let withIcons = g.chance(0.6)
        var rows: [RowSpec] = []
        for _ in 0..<g.int(1...5) {
            let symbol: String? = withIcons ? g.pick(Words.symbols) : nil
            let color = g.int(0...(Palette.count - 1))
            let kind = g.weighted([(0, 30.0), (1, 30.0), (2, 15.0), (3, 10.0), (4, 10.0), (5, 5.0)])
            switch kind {
            case 0:
                rows.append(.toggle(title: g.pick(Words.settingTitles), symbol: symbol, colorIndex: color, isOn: g.chance(0.5)))
            case 1:
                let detail: String? = g.chance(0.4) ? g.pick(Words.details) : nil
                rows.append(.navigation(title: g.pick(Words.settingTitles), symbol: symbol, colorIndex: color, detail: detail))
            case 2:
                rows.append(.value(title: g.pick(Words.settingTitles), detail: g.pick(Words.details)))
            case 3:
                rows.append(.textField(makeField(g, style: .rounded)))
            case 4:
                rows.append(.segmented(makeSegment(g)))
            default:
                rows.append(.subtitle(title: g.pick(Words.itemTitles), subtitle: g.pick(Words.sentences),
                                      symbol: g.pick(Words.symbols), colorIndex: color, trailing: nil))
            }
        }
        let header: String? = g.chance(0.6) ? g.pick(Words.sectionHeaders) : nil
        let footer: String? = g.chance(0.25) ? g.pick(Words.sentences) : nil
        return SectionSpec(header: header, footer: footer, rows: rows)
    }

    static func listSection(_ g: Gen) -> SectionSpec {
        let kind = g.weighted([(0, 60.0), (1, 30.0), (2, 10.0)])
        let withTrailing = g.chance(0.5)
        var rows: [RowSpec] = []
        for _ in 0..<g.int(5...12) {
            let color = g.int(0...(Palette.count - 1))
            switch kind {
            case 0:
                let trailing: String? = withTrailing ? g.pick(Words.trailings) : nil
                rows.append(.subtitle(title: g.pick(Words.itemTitles), subtitle: g.pick(Words.sentences),
                                      symbol: g.pick(Words.symbols), colorIndex: color, trailing: trailing))
            case 1:
                let detail: String? = withTrailing ? g.pick(Words.trailings) : nil
                rows.append(.navigation(title: g.pick(Words.itemTitles), symbol: g.pick(Words.symbols),
                                        colorIndex: color, detail: detail))
            default:
                rows.append(.toggle(title: g.pick(Words.itemTitles), symbol: g.pick(Words.symbols),
                                    colorIndex: color, isOn: g.chance(0.5)))
            }
        }
        let header: String? = g.chance(0.4) ? g.pick(Words.sectionHeaders) : nil
        return SectionSpec(header: header, footer: nil, rows: rows)
    }

    static func scrollBlocks(_ g: Gen) -> [BlockSpec] {
        var blocks: [BlockSpec] = []
        if g.chance(0.35) {
            blocks.append(.image(height: g.pick([140, 180, 220] as [CGFloat]),
                                 colorIndex: g.int(0...(Palette.count - 1)), symbol: g.pick(Words.symbols)))
        }
        if g.chance(0.7) { blocks.append(.heading(g.pick(Words.headings), large: g.chance(0.3))) }
        if g.chance(0.6) { blocks.append(.paragraph(g.pick(Words.sentences))) }

        for _ in 0..<g.int(3...8) {
            let kind = g.weighted([
                (0, 22.0), (1, 8.0), (2, 14.0), (3, 14.0), (4, 10.0),
                (5, 8.0), (6, 8.0), (7, 6.0), (8, 4.0), (9, 6.0),
            ])
            switch kind {
            case 0:
                blocks.append(.button(makeButton(g)))
            case 1:
                // Three free-width buttons overflow on small phones, so only equal-width rows get three.
                let equalWidth = g.chance(0.5)
                let count = equalWidth ? g.int(2...3) : 2
                blocks.append(.buttonRow((0..<count).map { _ in
                    makeButton(g, fullWidth: equalWidth, allowIconOnly: !equalWidth)
                }))
            case 2:
                blocks.append(.textField(makeField(g)))
            case 3:
                let subtitle: String? = g.chance(0.5) ? g.pick(Words.sentences) : nil
                blocks.append(.toggleCard(title: g.pick(Words.settingTitles), subtitle: subtitle, isOn: g.chance(0.5)))
            case 4:
                blocks.append(.segmented(makeSegment(g)))
            case 5:
                blocks.append(.paragraph(g.pick(Words.sentences)))
            case 6:
                blocks.append(.heading(g.pick(Words.headings), large: false))
            case 7:
                blocks.append(.iconLabel(symbol: g.pick(Words.symbols), text: g.pick(Words.sentences)))
            case 8:
                blocks.append(.progress(g.double(0.1...0.95)))
            default:
                blocks.append(.image(height: g.pick([120, 160, 200] as [CGFloat]),
                                     colorIndex: g.int(0...(Palette.count - 1)), symbol: g.pick(Words.symbols)))
            }
        }
        return blocks
    }

    static func authBlocks(_ g: Gen) -> [BlockSpec] {
        var blocks: [BlockSpec] = []
        if g.chance(0.5) {
            blocks.append(.image(height: g.pick([100, 140, 180] as [CGFloat]),
                                 colorIndex: g.int(0...(Palette.count - 1)), symbol: g.pick(Words.symbols)))
        }
        blocks.append(.heading(g.pick(Words.authHeadings), large: true))
        if g.chance(0.7) { blocks.append(.paragraph(g.pick(Words.sentences))) }

        let fieldStyle = g.weighted([
            (FieldStyleKind.rounded, 0.40),
            (FieldStyleKind.underlined, 0.25),
            (FieldStyleKind.filled, 0.35),
        ])
        if g.chance(0.3) {
            blocks.append(.textField(makeField(g, style: fieldStyle, secure: false, placeholder: "Full Name")))
        }
        blocks.append(.textField(makeField(g, style: fieldStyle, secure: false,
                                           placeholder: g.pick(["Email", "Email address", "Phone number", "Username"]))))
        if g.chance(0.85) {
            blocks.append(.textField(makeField(g, style: fieldStyle, secure: true, placeholder: "Password")))
        }
        if g.chance(0.3) {
            blocks.append(.toggleCard(title: "Remember me", subtitle: nil, isOn: g.chance(0.5)))
        }

        let primaryStyle: ButtonStyleKind = g.chance(0.6) ? .prominent : .custom
        blocks.append(.button(makeButton(g, fullWidth: true, allowIconOnly: false,
                                         preferredStyle: primaryStyle, title: g.pick(Words.authPrimary))))
        if g.chance(0.6) {
            blocks.append(.button(makeButton(g, fullWidth: false, allowIconOnly: false,
                                             preferredStyle: .borderless, title: g.pick(Words.authSecondary))))
        }
        if g.chance(0.4) {
            blocks.append(.divider)
            let options = g.sample(Words.altSignIn, count: g.int(2...3))
            if g.chance(0.5) {
                let buttons = options.map { option in
                    makeButton(g, fullWidth: true, allowIconOnly: false, preferredStyle: .bordered,
                               title: option.title, symbol: option.symbol)
                }
                blocks.append(.buttonRow(buttons))
            } else {
                for option in options {
                    blocks.append(.button(makeButton(g, fullWidth: true, allowIconOnly: false, preferredStyle: .bordered,
                                                     title: option.title, symbol: option.symbol)))
                }
            }
        }
        return blocks
    }
}
