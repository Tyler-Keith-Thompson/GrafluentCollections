// Stabbing queries on an IntervalTree against a linear filter over the same intervals: 10⁵
// intervals of length 1 to 100 over 0 ..< 10⁶, and 1,000 seeded random points. The filter
// tests every interval per point and the tree descends about 2 log n vertices plus a few per
// interval found, each a cache miss into a 10⁵-vertex tree, so the tree must be at least 15×
// faster; the gap measured on a laptop is about 50×, so the bound leaves room for a busy
// machine. The two sides are timed in
// alternating rounds, each keeping its fastest of seven. The timing runs only in an optimized
// build; a debug build checks on 10³ intervals that both sides agree.

import GrafluentCollectionsTestSupport
import RangeTrees
import Testing

@Suite("IntervalTree stabbing queries against a linear filter")
struct IntervalTreeRatioTests {
    @Test("IntervalTree: containing(_:) over 10⁵ intervals is at least 15× faster than a linear filter", .timeLimit(.minutes(1)))
    func stabbingBeatsFilter() async {
        await Task {
            #if DEBUG
            let n = 1_000
            #else
            let n = 100_000
            #endif
            var rng = SeededRandomNumberGenerator(seed: 18)
            let entries = (0 ..< n).map { k -> IntervalTree<Int, Int>.Entry in
                let lower = Int.random(in: 0 ..< 1_000_000, using: &rng)
                return .init(range: lower ..< lower + Int.random(in: 1 ... 100, using: &rng), value: k)
            }
            let points = (0 ..< 1_000).map { _ in Int.random(in: 0 ..< 1_000_000, using: &rng) }
            let tree = IntervalTree(entries)
            let ranges = entries.map(\.range)

            func library() -> Int {
                var found = 0
                for point in points {
                    for entry in tree.containing(point) {
                        found &+= entry.value
                    }
                }
                return found
            }
            func filter() -> Int {
                ranges.withUnsafeBufferPointer { ranges in
                    var found = 0
                    for point in points {
                        for (k, range) in ranges.enumerated() where range.lowerBound <= point && point < range.upperBound {
                            found &+= k
                        }
                    }
                    return found
                }
            }
            #expect(library() == filter())

            #if !DEBUG
            let clock = ContinuousClock()
            var libraryTime = Duration.seconds(1_000), baselineTime = Duration.seconds(1_000)
            var sink = 0
            for _ in 0 ..< 7 {
                libraryTime = min(libraryTime, clock.measure { sink &+= library() })
                baselineTime = min(baselineTime, clock.measure { sink &+= filter() })
            }
            #expect(sink != 1)
            let speedup = baselineTime / libraryTime
            #expect(speedup > 15, "containing(_:) was only \(speedup)× faster than a linear filter")
            #endif
        }.value
    }
}
