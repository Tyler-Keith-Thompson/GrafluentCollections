import Benchmark
import SuffixStructures

let benchmarks: @Sendable () -> Void = {
    Benchmark.defaultConfiguration.metrics = [.wallClock, .mallocCountTotal, .instructions]
    Benchmark.defaultConfiguration.maxDuration = .seconds(2)

    // A seeded linear congruential generator, so every run sees the same text: 10⁶ letters of
    // A, C, G and T, a text of 10⁵ lowercase Characters, and 10⁴ eight-letter patterns, half of
    // them cut from the text.
    var state: UInt64 = 10
    func next(below bound: Int) -> Int {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Int(truncatingIfNeeded: state >> 33) % bound
    }
    let letters: [UInt8] = Array("ACGT".utf8)
    let bytes = (0 ..< 1_000_000).map { _ in letters[next(below: 4)] }
    let characters = String((0 ..< 100_000).map { _ in Character(Unicode.Scalar(UInt8(97 + next(below: 26)))) })
    let patterns: [[UInt8]] = (0 ..< 10_000).map { k in
        if k % 2 == 0 {
            let start = next(below: bytes.count - 8)
            return Array(bytes[start ..< start + 8])
        }
        return (0 ..< 8).map { _ in letters[next(below: 4)] }
    }

    // The hand-written form the library must keep pace with: sorting the positions by comparing
    // the suffixes.
    Benchmark("SuffixStructures: BASELINE comparison sort of the suffixes") { benchmark in
        for _ in benchmark.scaledIterations {
            bytes.withUnsafeBufferPointer { text in
                var order = Array(0 ..< text.count)
                order.sort { a, b in
                    var a = a, b = b
                    while a < text.count && b < text.count {
                        if text[a] != text[b] { return text[a] < text[b] }
                        a &+= 1
                        b &+= 1
                    }
                    return a == text.count
                }
                blackHole(order)
            }
        }
    }

    Benchmark("SuffixStructures: SuffixArray<UInt8>.init(_:)") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(SuffixArray(bytes))
        }
    }

    Benchmark("SuffixStructures: SuffixArray<Character>.init(_:) on 10⁵ symbols") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(SuffixArray(characters))
        }
    }

    Benchmark("SuffixStructures: SuffixArray<UInt8>.occurrences(of:)") { benchmark in
        let suffixes = SuffixArray(bytes)
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            var found = 0
            for pattern in patterns {
                found &+= suffixes.occurrences(of: pattern).count
            }
            blackHole(found)
        }
        benchmark.stopMeasurement()
    }

    // A suffix trie built by inserting every suffix of a short text symbol by symbol, children
    // in sibling chains: the O(n²) form the suffix tree replaces.
    let short = Array(bytes.prefix(2_000))
    Benchmark("SuffixStructures: BASELINE naive suffix trie on 2000 symbols") { benchmark in
        for _ in benchmark.scaledIterations {
            var symbols: [UInt8] = [0]
            var firstChildren: [Int32] = [-1]
            var nextSiblings: [Int32] = [-1]
            for start in short.indices {
                var node = 0
                for position in start ..< short.count {
                    let symbol = short[position]
                    var child = Int(firstChildren[node])
                    while child >= 0 && symbols[child] != symbol {
                        child = Int(nextSiblings[child])
                    }
                    if child < 0 {
                        child = symbols.count
                        symbols.append(symbol)
                        firstChildren.append(-1)
                        nextSiblings.append(firstChildren[node])
                        firstChildren[node] = Int32(child)
                    }
                    node = child
                }
            }
            blackHole(symbols.count)
        }
    }

    Benchmark("SuffixStructures: SuffixTree<UInt8>.init(_:) on 2000 symbols") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(SuffixTree(short))
        }
    }

    Benchmark(
        "SuffixStructures: SuffixTree<UInt8>.init(_:)",
        configuration: .init(metrics: [.wallClock, .mallocCountTotal, .instructions, .peakMemoryResident])
    ) { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(SuffixTree(bytes))
        }
    }

    Benchmark("SuffixStructures: SuffixTree<UInt8>.contains(_:)") { benchmark in
        let tree = SuffixTree(bytes)
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            var found = 0
            for pattern in patterns where tree.contains(pattern) {
                found &+= 1
            }
            blackHole(found)
        }
        benchmark.stopMeasurement()
    }
}
