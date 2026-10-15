import SwiftUI

// MARK: - Root

struct SynthRootView: View {
    let spec: ScreenSpec
    @State private var selectedTab: Int

    init(spec: ScreenSpec) {
        self.spec = spec
        _selectedTab = State(initialValue: spec.selectedTab)
    }

    var body: some View {
        content
            .tint(Palette.colors[spec.tintIndex])
            .preferredColorScheme(spec.dark ? .dark : .light)
    }

    @ViewBuilder private var content: some View {
        if spec.tabs.isEmpty {
            ScreenContent(spec: spec)
        } else {
            TabView(selection: $selectedTab) {
                ForEach(Array(spec.tabs.enumerated()), id: \.offset) { index, tab in
                    Group {
                        if index == spec.selectedTab {
                            ScreenContent(spec: spec)
                        } else {
                            Color.clear
                        }
                    }
                    .tabItem { Label(tab.title, systemImage: tab.symbol) }
                    .tag(index)
                }
            }
        }
    }
}

// MARK: - Screen

struct ScreenContent: View {
    let spec: ScreenSpec
    @State private var searchText = ""

    var body: some View {
        if spec.showsNavBar {
            NavigationStack {
                decoratedBody
                    .navigationTitle(spec.title)
                    .navigationBarTitleDisplayMode(spec.largeTitle ? .large : .inline)
                    .modifier(OptionalSearchable(enabled: spec.searchable, prompt: spec.searchPrompt, text: $searchText))
            }
        } else {
            decoratedBody
        }
    }

    @ViewBuilder private var decoratedBody: some View {
        if let bottom = spec.bottomButton {
            mainBody.safeAreaInset(edge: .bottom) {
                SynthButton(spec: bottom)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.bar)
            }
        } else {
            mainBody
        }
    }

    @ViewBuilder private var mainBody: some View {
        switch spec.archetype {
        case .settingsForm, .plainList:
            ListBody(spec: spec)
        case .scrollContent, .authForm:
            ScrollBody(spec: spec)
        }
    }
}

struct OptionalSearchable: ViewModifier {
    let enabled: Bool
    let prompt: String
    @Binding var text: String

    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled {
            content.searchable(text: $text, placement: .navigationBarDrawer(displayMode: .always), prompt: prompt)
        } else {
            content
        }
    }
}

// MARK: - List screens

struct ListBody: View {
    let spec: ScreenSpec

    var body: some View {
        switch spec.listStyle {
        case .insetGrouped: list.listStyle(.insetGrouped)
        case .grouped: list.listStyle(.grouped)
        case .plain: list.listStyle(.plain)
        }
    }

    private var list: some View {
        List {
            ForEach(Array(spec.sections.enumerated()), id: \.offset) { _, section in
                Section {
                    ForEach(Array(section.rows.enumerated()), id: \.offset) { _, row in
                        RowView(row: row)
                    }
                } header: {
                    if let header = section.header { Text(header) }
                } footer: {
                    if let footer = section.footer { Text(footer) }
                }
            }
        }
    }
}

struct RowView: View {
    let row: RowSpec
    @State private var isOn = false
    @State private var text = ""
    @State private var selection = 0

    init(row: RowSpec) {
        self.row = row
        switch row {
        case let .toggle(_, _, _, on): _isOn = State(initialValue: on)
        case let .textField(field): _text = State(initialValue: field.prefilled ?? "")
        case let .segmented(segment): _selection = State(initialValue: segment.selected)
        default: break
        }
    }

    var body: some View {
        // Marks real rows so the labeller can skip section header/footer cells.
        rowContent.accessibilityIdentifier("synth.row")
    }

    @ViewBuilder private var rowContent: some View {
        switch row {
        case let .toggle(title, symbol, colorIndex, _):
            HStack {
                RowLabel(title: title, symbol: symbol, colorIndex: colorIndex)
                Spacer(minLength: 8)
                // labelsHidden keeps the switch's accessibility frame tight around the control,
                // so the bounding box matches the visible switch rather than the whole row.
                Toggle(title, isOn: $isOn).labelsHidden()
            }
        case let .navigation(title, symbol, colorIndex, detail):
            HStack {
                RowLabel(title: title, symbol: symbol, colorIndex: colorIndex)
                Spacer(minLength: 8)
                if let detail {
                    Text(detail).foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        case let .value(title, detail):
            LabeledContent(title, value: detail)
        case let .textField(field):
            SynthTextField(spec: field, text: $text, inForm: true)
        case let .segmented(segment):
            SegmentedPicker(spec: segment, selection: $selection)
        case let .subtitle(title, subtitle, symbol, colorIndex, trailing):
            HStack(spacing: 12) {
                IconTile(symbol: symbol, colorIndex: colorIndex, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.body.weight(.medium))
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer(minLength: 8)
                if let trailing {
                    Text(trailing).font(.footnote).foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 2)
        }
    }
}

struct RowLabel: View {
    let title: String
    let symbol: String?
    let colorIndex: Int

    var body: some View {
        HStack(spacing: 12) {
            if let symbol {
                IconTile(symbol: symbol, colorIndex: colorIndex, size: 29)
            }
            Text(title)
        }
    }
}

struct IconTile: View {
    let symbol: String
    let colorIndex: Int
    let size: CGFloat

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                    .fill(Palette.colors[colorIndex])
            )
            .accessibilityHidden(true)
    }
}

// MARK: - Scroll screens

struct ScrollBody: View {
    let spec: ScreenSpec

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: spec.spacing) {
                ForEach(Array(spec.blocks.enumerated()), id: \.offset) { _, block in
                    BlockView(block: block)
                }
            }
            .padding(.horizontal, spec.horizontalPadding)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(spec.groupedBackground
                    ? Color(uiColor: .systemGroupedBackground)
                    : Color(uiColor: .systemBackground))
    }
}

struct BlockView: View {
    let block: BlockSpec
    @State private var isOn = false
    @State private var text = ""
    @State private var selection = 0

    init(block: BlockSpec) {
        self.block = block
        switch block {
        case let .toggleCard(_, _, on): _isOn = State(initialValue: on)
        case let .textField(field): _text = State(initialValue: field.prefilled ?? "")
        case let .segmented(segment): _selection = State(initialValue: segment.selected)
        default: break
        }
    }

    var body: some View {
        switch block {
        case let .heading(text, large):
            Text(text).font(large ? Font.largeTitle.bold() : Font.title2.bold())
        case let .paragraph(text):
            Text(text).font(.body).foregroundStyle(.secondary)
        case let .button(button):
            SynthButton(spec: button)
        case let .buttonRow(buttons):
            HStack(spacing: 12) {
                ForEach(Array(buttons.enumerated()), id: \.offset) { _, button in
                    SynthButton(spec: button)
                }
            }
        case let .textField(field):
            SynthTextField(spec: field, text: $text, inForm: false)
        case let .toggleCard(title, subtitle, _):
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.body.weight(.medium))
                    if let subtitle {
                        Text(subtitle).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                Toggle(title, isOn: $isOn).labelsHidden()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground))
            )
        case let .segmented(segment):
            SegmentedPicker(spec: segment, selection: $selection)
        case let .image(height, colorIndex, symbol):
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Palette.colors[colorIndex].gradient)
                Image(systemName: symbol)
                    .font(.system(size: 44))
                    .foregroundStyle(Color.white.opacity(0.9))
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .accessibilityHidden(true)
        case let .iconLabel(symbol, text):
            Label(text, systemImage: symbol).font(.subheadline)
        case let .progress(value):
            ProgressView(value: value)
        case .divider:
            Divider()
        }
    }
}

// MARK: - Controls

struct SynthTextField: View {
    let spec: FieldSpec
    @Binding var text: String
    let inForm: Bool

    var body: some View {
        if inForm {
            field
        } else {
            switch spec.style {
            case .rounded:
                field.textFieldStyle(.roundedBorder)
            case .underlined:
                VStack(spacing: 6) {
                    field
                    Rectangle().fill(Color(uiColor: .separator)).frame(height: 1)
                }
            case .filled:
                field
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(uiColor: .secondarySystemBackground))
                    )
            }
        }
    }

    @ViewBuilder private var field: some View {
        if spec.secure {
            SecureField(spec.placeholder, text: $text)
        } else {
            TextField(spec.placeholder, text: $text)
        }
    }
}

struct SegmentedPicker: View {
    let spec: SegmentSpec
    @Binding var selection: Int

    var body: some View {
        Picker("Options", selection: $selection) {
            ForEach(Array(spec.options.enumerated()), id: \.offset) { index, option in
                Text(option).tag(index)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
}

struct SynthButton: View {
    let spec: ButtonSpec

    var body: some View {
        styledButton
            .accessibilityIdentifier(spec.id)
    }

    @ViewBuilder private var labelContent: some View {
        if let symbol = spec.symbol {
            if spec.iconOnly {
                Image(systemName: symbol).accessibilityLabel(spec.title)
            } else {
                Label(spec.title, systemImage: symbol)
            }
        } else {
            Text(spec.title)
        }
    }

    private var shape: ButtonBorderShape {
        spec.capsule ? .capsule : .roundedRectangle
    }

    @ViewBuilder private var styledButton: some View {
        switch spec.style {
        case .prominent:
            Button {} label: {
                labelContent.frame(maxWidth: spec.fullWidth ? .infinity : nil)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(shape)
            .controlSize(spec.size.controlSize)
        case .bordered:
            Button {} label: {
                labelContent.frame(maxWidth: spec.fullWidth ? .infinity : nil)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(shape)
            .controlSize(spec.size.controlSize)
        case .borderless:
            Button {} label: {
                labelContent
            }
            .buttonStyle(.borderless)
            .controlSize(spec.size.controlSize)
        case .custom:
            // Hand-styled button, like many real-world apps use instead of system styles.
            Button {} label: {
                labelContent
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.vertical, spec.size.customVerticalPadding)
                    .padding(.horizontal, 20)
                    .frame(maxWidth: spec.fullWidth ? .infinity : nil)
                    .background(
                        RoundedRectangle(cornerRadius: spec.capsule ? 999 : spec.cornerRadius, style: .continuous)
                            .fill(Palette.colors[spec.colorIndex])
                    )
            }
            .buttonStyle(.plain)
        }
    }
}
