// Overlapping pairs from an MXCIFQuadtree against testing every pair of the same boxes: 10⁴
// seeded random boxes up to 0.01 on a side in the unit square. The pairwise test reads 5 · 10⁷
// pairs and the tree a few cells per box, so the tree must be at least 10× faster; the simulated
// count at 2,000 boxes is already about 20× fewer instructions, and the gap grows with the
// count, so the bound leaves room for a busy machine. The two sides are timed in alternating
// rounds, each keeping its fastest of seven. The timing runs only in an optimized build; a debug
// build checks on 300 boxes that both sides agree.

import GrafluentCollectionsTestSupport
import SpatialTrees
import Testing

@Suite("MXCIFQuadtree overlapping pairs against testing every pair")
struct MXCIFQuadtreeRatioTests {
    @Test("MXCIFQuadtree: overlappingPairs() over 10⁴ boxes is at least 10× faster than testing every pair", .timeLimit(.minutes(1)))
    func pairsBeatEveryPair() async {
        await Task {
            #if DEBUG
            let n = 300
            #else
            let n = 10_000
            #endif
            var rng = SeededRandomNumberGenerator(seed: 36)
            let boxes = (0 ..< n).map { _ -> BoundingBox<SIMD2<Double>> in
                let corner = SIMD2<Double>(Double.random(in: 0 ..< 0.99, using: &rng), Double.random(in: 0 ..< 0.99, using: &rng))
                let size = SIMD2<Double>(Double.random(in: 0 ... 0.01, using: &rng), Double.random(in: 0 ... 0.01, using: &rng))
                return BoundingBox(lower: corner, upper: corner + size)
            }
            var tree = MXCIFQuadtree<Int>(bounds: BoundingBox(lower: [0, 0], upper: [1, 1]))
            for (k, box) in boxes.enumerated() {
                tree.insert(k, in: box)
            }

            func library() -> Int {
                var sink = 0
                for pair in tree.overlappingPairs() {
                    sink &+= pair.first.element &* pair.second.element
                }
                return sink
            }
            func everyPair() -> Int {
                boxes.withUnsafeBufferPointer { boxes in
                    var sink = 0
                    for i in boxes.indices {
                        for j in i + 1 ..< boxes.count where boxes[i].intersects(boxes[j]) {
                            sink &+= i &* j
                        }
                    }
                    return sink
                }
            }
            #expect(library() == everyPair())

            #if !DEBUG
            let clock = ContinuousClock()
            var libraryTime = Duration.seconds(1_000), baselineTime = Duration.seconds(1_000)
            var sink = 0
            for _ in 0 ..< 7 {
                libraryTime = min(libraryTime, clock.measure { sink &+= library() })
                baselineTime = min(baselineTime, clock.measure { sink &+= everyPair() })
            }
            #expect(sink != 1)
            let speedup = baselineTime / libraryTime
            #expect(speedup > 10, "overlappingPairs() was only \(speedup)× faster than testing every pair")
            #endif
        }.value
    }
}
