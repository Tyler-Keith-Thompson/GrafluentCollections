// Range minima from a SegmentTree, and range adds into a LazySegmentTree, against loops over the
// same array, on 10⁶ elements and 2,000 seeded random ranges. A loop reads a third of the array
// per range on average and a tree about forty cells (eighty for a lazy update, which also writes
// them), so the segment tree must be at least 50× faster and the lazy one 20×; the gaps measured
// on a laptop are about 650× and 130×, so the bounds leave room for a busy machine. The two sides are timed in alternating rounds, each keeping its fastest of seven. The
// timing runs only in an optimized build; a debug build checks on 10³ elements that both sides
// agree.

import GrafluentCollectionsTestSupport
import RangeTrees
import Testing

@Suite("SegmentTree and LazySegmentTree against loops")
struct SegmentTreeRatioTests {
    @Test("SegmentTree: range minima on 10⁶ elements are at least 50× faster than a linear scan", .timeLimit(.minutes(1)))
    func rangeMinimaBeatScan() async {
        await Task {
            #if DEBUG
            let n = 1_000
            #else
            let n = 1_000_000
            #endif
            var rng = SeededRandomNumberGenerator(seed: 16)
            let values = (0 ..< n).map { _ in Int.random(in: -1_000 ... 1_000, using: &rng) }
            let ranges = (0 ..< 2_000).map { _ in
                let x = Int.random(in: 0 ... n, using: &rng), y = Int.random(in: 0 ... n, using: &rng)
                return min(x, y) ..< max(x, y)
            }
            let tree = SegmentTree<Minimum<Int>>(values)

            func library() -> Int {
                var sink = 0
                for range in ranges {
                    sink &+= tree.combined(in: range)
                }
                return sink
            }
            func scan() -> Int {
                values.withUnsafeBufferPointer { values in
                    var sink = 0
                    for range in ranges {
                        var minimum = Int.max
                        for k in range {
                            minimum = min(minimum, values[k])
                        }
                        sink &+= minimum
                    }
                    return sink
                }
            }
            #expect(library() == scan())

            #if !DEBUG
            let clock = ContinuousClock()
            var libraryTime = Duration.seconds(1_000), baselineTime = Duration.seconds(1_000)
            var sink = 0
            for _ in 0 ..< 7 {
                libraryTime = min(libraryTime, clock.measure { sink &+= library() })
                baselineTime = min(baselineTime, clock.measure { sink &+= scan() })
            }
            #expect(sink != 1)
            let speedup = baselineTime / libraryTime
            #expect(speedup > 50, "combined(in:) was only \(speedup)× faster than a linear scan")
            #endif
        }.value
    }

    @Test("LazySegmentTree: range adds on 10⁶ elements are at least 20× faster than a loop", .timeLimit(.minutes(1)))
    func rangeAddsBeatLoop() async {
        await Task {
            enum AddToSum: MonoidAction {
                typealias Values = Sum<Int>
                static var identity: Int { 0 }
                static func compose(_ outer: Int, _ inner: Int) -> Int { outer &+ inner }
                static func apply(_ update: Int, to sum: Int, count: Int) -> Int { sum &+ update &* count }
            }
            #if DEBUG
            let n = 1_000
            #else
            let n = 1_000_000
            #endif
            var rng = SeededRandomNumberGenerator(seed: 17)
            let values = (0 ..< n).map { _ in Int.random(in: -1_000 ... 1_000, using: &rng) }
            let updates = (0 ..< 2_000).map { _ in
                let x = Int.random(in: 0 ... n, using: &rng), y = Int.random(in: 0 ... n, using: &rng)
                return (range: min(x, y) ..< max(x, y), amount: Int.random(in: -9 ... 9, using: &rng))
            }

            var tree = LazySegmentTree<AddToSum>(values)
            var array = values
            func library() {
                for update in updates {
                    tree.apply(update.amount, in: update.range)
                }
            }
            func loop() {
                array.withUnsafeMutableBufferPointer { array in
                    for update in updates {
                        for k in update.range {
                            array[k] &+= update.amount
                        }
                    }
                }
            }
            library()
            loop()
            #expect(Array(tree) == array)

            #if !DEBUG
            // Each round applies the same updates again to the tree and the array built above.
            let clock = ContinuousClock()
            var libraryTime = Duration.seconds(1_000), baselineTime = Duration.seconds(1_000)
            for _ in 0 ..< 7 {
                libraryTime = min(libraryTime, clock.measure { library() })
                baselineTime = min(baselineTime, clock.measure { loop() })
            }
            #expect(tree.combined(in: 0 ..< n) == array.reduce(0, &+))
            let speedup = baselineTime / libraryTime
            #expect(speedup > 20, "apply(_:in:) was only \(speedup)× faster than a loop")
            #endif
        }.value
    }
}
