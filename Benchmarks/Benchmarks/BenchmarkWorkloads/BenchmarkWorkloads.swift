/// SplitMix64 (Steele, Lea and Flood, "Fast Splittable Pseudorandom Number Generators", 2014): a
/// seeded generator, so every run of a benchmark sees the same keys.
public struct SplitMix64: RandomNumberGenerator, Sendable {
    public var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// The keys of a set workload: `count` distinct even keys in random order, the same keys
/// ascending, and as many odd probes, which no set of the keys contains.
public struct IntegerWorkload: Sendable {
    public let keys: [Int]
    public let ascending: [Int]
    public let misses: [Int]

    public init(count: Int, seed: UInt64) {
        var generator = SplitMix64(seed: seed)
        var keys = (0 ..< count).map { 2 * $0 }
        keys.shuffle(using: &generator)
        self.keys = keys
        ascending = (0 ..< count).map { 2 * $0 }
        misses = keys.map { $0 + 1 }
    }
}
