// Box queries on a Quadtree against a brute-force scan of the same points: 10⁵ seeded random
// points in the unit square and 1,000 boxes 0.01 on a side, about ten points each. The scan
// tests every point per box and the tree a few cells, so the tree must be at least 60× faster;
// the gap measured on a laptop is about 200×, so the bound leaves room for a busy machine.
// The two sides are timed in alternating rounds, each keeping its fastest of seven. The timing
// runs only in an optimized build; a debug build checks on 10³ points that both sides agree.

import GrafluentCollectionsTestSupport
import SpatialTrees
import Testing

@Suite("Quadtree box queries against brute force")
struct QuadtreeRatioTests {
    @Test("Quadtree: items(in:) over 10⁵ points is at least 60× faster than a scan", .timeLimit(.minutes(1)))
    func boxQueriesBeatScan() async {
        await Task {
            #if DEBUG
            let n = 1_000
            #else
            let n = 100_000
            #endif
            var rng = SeededRandomNumberGenerator(seed: 20)
            let points: [SIMD2<Double>] = (0 ..< n).map { _ in [Double.random(in: 0 ..< 1, using: &rng), Double.random(in: 0 ..< 1, using: &rng)] }
            let boxes = (0 ..< 1_000).map { _ -> BoundingBox<SIMD2<Double>> in
                let corner = SIMD2<Double>(Double.random(in: 0 ..< 1, using: &rng), Double.random(in: 0 ..< 1, using: &rng))
                return BoundingBox(lower: corner, upper: corner + [0.01, 0.01])
            }
            var tree = Quadtree<Int>(bounds: BoundingBox(lower: [0, 0], upper: [1, 1]))
            for (k, point) in points.enumerated() {
                tree.insert(k, at: point)
            }

            func library() -> Int {
                var sink = 0
                for box in boxes {
                    for item in tree.items(in: box) {
                        sink &+= item.element
                    }
                }
                return sink
            }
            func scan() -> Int {
                points.withUnsafeBufferPointer { points in
                    var sink = 0
                    for box in boxes {
                        for k in points.indices where box.contains(points[k]) {
                            sink &+= k
                        }
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
            #expect(speedup > 60, "items(in:) was only \(speedup)× faster than a scan")
            #endif
        }.value
    }
}
