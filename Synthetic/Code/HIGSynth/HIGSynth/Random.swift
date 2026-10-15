import Foundation

/// SplitMix64 – tiny, fast, deterministic RNG so a seed always yields the same screen.
struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Convenience helpers on top of the seeded RNG.
final class Gen {
    private var rng: SeededRNG
    private var buttonCounter = 0

    init(seed: UInt64) {
        rng = SeededRNG(seed: seed)
    }

    func chance(_ probability: Double) -> Bool {
        Double.random(in: 0..<1, using: &rng) < probability
    }

    func int(_ range: ClosedRange<Int>) -> Int {
        Int.random(in: range, using: &rng)
    }

    func double(_ range: ClosedRange<Double>) -> Double {
        Double.random(in: range, using: &rng)
    }

    func pick<T>(_ items: [T]) -> T {
        items[int(0...(items.count - 1))]
    }

    func weighted<T>(_ items: [(T, Double)]) -> T {
        let total = items.reduce(0) { $0 + $1.1 }
        var roll = Double.random(in: 0..<total, using: &rng)
        for (item, weight) in items {
            if roll < weight { return item }
            roll -= weight
        }
        return items[items.count - 1].0
    }

    func sample<T>(_ items: [T], count: Int) -> [T] {
        Array(items.shuffled(using: &rng).prefix(count))
    }

    /// Every generated button gets a unique identifier starting with `synth.button`
    /// so the UI test can tell "our" buttons apart from system buttons (tab items, etc.).
    func nextButtonID() -> String {
        buttonCounter += 1
        return "synth.button.\(buttonCounter)"
    }
}
