// BTree.contains against binary search in a sorted array of the same 10⁶ distinct elements, on
// 10⁵ seeded random probes, half of them present. A B-tree binary-searches about four nodes of up
// to 63 elements each, so it makes about as many comparisons as the array's binary search and
// follows a node reference per level; it may be slower by a constant factor: about 1.3–1.6× on a
// laptop, bounded here at 2.5×. The two sides are timed in alternating rounds, each keeping its
// fastest of seven. The timing runs only in an optimized build; a debug build checks on 10³
// elements that both sides agree.

import BTrees
import GrafluentCollectionsTestSupport
import Testing

@Suite("B-tree lookups against binary search in a sorted array")
struct BTreeRatioTests {
    @Test("BTree: contains(_:) on 10⁶ elements is within 2.5× of binary search in a sorted array", .timeLimit(.minutes(1)))
    func containsKeepsPaceWithBinarySearch() async {
        await Task {
            #if DEBUG
            let n = 1_000
            #else
            let n = 1_000_000
            #endif
            var rng = SeededRandomNumberGenerator(seed: 1)
            let sorted = (0 ..< n).map { $0 * 2 }
            let tree = BTree(sorted.shuffled(using: &rng))
            let probes = (0 ..< 100_000).map { _ in Int.random(in: 0 ..< 2 * n, using: &rng) }

            func lookups() -> Int {
                var found = 0
                for probe in probes where tree.contains(probe) {
                    found &+= 1
                }
                return found
            }
            func binarySearch() -> Int {
                sorted.withUnsafeBufferPointer { sorted in
                    var found = 0
                    for probe in probes {
                        var low = 0
                        var high = sorted.count
                        while low < high {
                            let middle = low &+ (high &- low) / 2
                            if sorted[middle] < probe {
                                low = middle &+ 1
                            } else {
                                high = middle
                            }
                        }
                        if low < sorted.count && sorted[low] == probe {
                            found &+= 1
                        }
                    }
                    return found
                }
            }
            #expect(lookups() == binarySearch())

            #if !DEBUG
            let clock = ContinuousClock()
            var library = Duration.seconds(1_000), baseline = Duration.seconds(1_000)
            var sink = 0
            for _ in 0 ..< 7 {
                library = min(library, clock.measure { sink &+= lookups() })
                baseline = min(baseline, clock.measure { sink &+= binarySearch() })
            }
            #expect(sink != 1)
            let ratio = library / baseline
            #expect(ratio < 2.5, "contains(_:) took \(ratio)× binary search")
            #endif
        }.value
    }
}
