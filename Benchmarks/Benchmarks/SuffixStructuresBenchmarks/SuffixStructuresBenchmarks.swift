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
}
