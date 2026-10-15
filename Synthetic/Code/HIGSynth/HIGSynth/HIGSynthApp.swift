import SwiftUI

/// Renders one randomly generated, but fully deterministic, screen.
///
/// Launch with `-seed <number>` to get the same screen every time.
/// Without a seed (e.g. pressing Run in Xcode) you get a random screen,
/// which is handy for eyeballing what the generator produces.
@main
struct HIGSynthApp: App {
    private let spec: ScreenSpec = {
        let args = ProcessInfo.processInfo.arguments
        var seed = UInt64.random(in: 0...UInt64(UInt32.max))
        if let index = args.firstIndex(of: "-seed"), index + 1 < args.count, let value = UInt64(args[index + 1]) {
            seed = value
        }
        print("HIGSynth: rendering seed \(seed)")
        return ScreenSpec.generate(seed: seed)
    }()

    var body: some Scene {
        WindowGroup {
            SynthRootView(spec: spec)
        }
    }
}
