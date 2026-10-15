import PhotosUI
import SwiftUI

struct ContentView: View {
    @State private var analyzer = Analyzer()
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("HIG Check")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        PhotosPicker(selection: $pickerItem, matching: .screenshots) {
                            Label("Choose Screenshot", systemImage: "photo.badge.plus")
                        }
                    }
                }
                .onChange(of: pickerItem) { _, item in
                    guard let item else { return }
                    Task { await load(item) }
                }
        }
    }

    @ViewBuilder private var content: some View {
        switch analyzer.state {
        case .idle:
            ContentUnavailableView {
                Label("No Screenshot", systemImage: "iphone")
            } description: {
                Text("Choose a screenshot of an iPhone app to check its buttons, list rows, switches and tab bar against Apple's Human Interface Guidelines.")
            } actions: {
                choosePickerButton
            }
        case .analyzing:
            ProgressView("Checking Screenshot…")
        case .done(let result):
            ResultsView(result: result)
        case .failed(let message):
            ContentUnavailableView {
                Label("Couldn't Check Screenshot", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                choosePickerButton
            }
        }
    }

    private var choosePickerButton: some View {
        PhotosPicker(selection: $pickerItem, matching: .screenshots) {
            Text("Choose Screenshot")
        }
        .buttonStyle(.borderedProminent)
    }

    private func load(_ item: PhotosPickerItem) async {
        defer { pickerItem = nil }   // so picking the same screenshot again still triggers a check
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            analyzer.fail("That image couldn't be loaded. Try another screenshot.")
            return
        }
        await analyzer.analyze(image)
    }
}

#Preview {
    ContentView()
}
