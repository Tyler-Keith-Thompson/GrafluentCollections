// Prefix sums from a FenwickTree against a linear scan of the same values, on 10⁶ elements and
// 2,000 seeded random queries. A scan reads half the array per query on average and a Fenwick
// tree about twenty cells, so the tree must be at least 50× faster; the gap measured on a laptop
// is about 1,800×, so the bound leaves room for a busy machine. The two sides are timed in
// alternating rounds, each keeping its fastest of seven. The timing runs only in an optimized
// build; a debug build checks on 10³ elements that both sides agree.

import GrafluentCollectionsTestSupport
import RangeTrees
import Testing

@Suite("FenwickTree prefix sums against a linear scan")
struct FenwickTreeRatioTests {
    @Test("FenwickTree: prefixSum(through:) on 10⁶ elements is at least 50× faster than a linear scan", .timeLimit(.minutes(1)))
    func prefixSumBeatsScan() async {
        await Task {
            #if DEBUG
            let n = 1_000
            #else
            let n = 1_000_000
            #endif
            var rng = SeededRandomNumberGenerator(seed: 15)
            let values = (0 ..< n).map { _ in Int.random(in: -1_000 ... 1_000, using: &rng) }
            let queries = (0 ..< 2_000).map { _ in Int.random(in: 0 ..< n, using: &rng) }
            let tree = FenwickTree(values)

            func fenwick() -> Int {
                var sink = 0
                for query in queries {
                    sink &+= tree.prefixSum(through: query)
                }
                return sink
            }
            func scan() -> Int {
                values.withUnsafeBufferPointer { values in
                    var sink = 0
                    for query in queries {
                        var sum = 0
                        for k in 0 ... query {
                            sum &+= values[k]
                        }
                        sink &+= sum
                    }
                    return sink
                }
            }
            #expect(fenwick() == scan())

            #if !DEBUG
            let clock = ContinuousClock()
            var library = Duration.seconds(1_000), baseline = Duration.seconds(1_000)
            var sink = 0
            for _ in 0 ..< 7 {
                library = min(library, clock.measure { sink &+= fenwick() })
                baseline = min(baseline, clock.measure { sink &+= scan() })
            }
            #expect(sink != 1)
            let speedup = baseline / library
            #expect(speedup > 50, "prefixSum(through:) was only \(speedup)× faster than a linear scan")
            #endif
        }.value
    }
}
