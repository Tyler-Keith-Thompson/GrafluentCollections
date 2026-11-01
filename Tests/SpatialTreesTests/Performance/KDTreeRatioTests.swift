// Nearest-neighbour queries on a KDTree against a brute-force scan of the same points: 10⁵
// seeded random points in the unit square and 1,000 queries. The scan measures the distance to
// every point per query and the tree visits a few dozen, so the tree must be at least 100×
// faster; the gap measured on a laptop is about 330×, so the bound leaves room for a busy
// machine. The two sides are timed in alternating rounds, each keeping its fastest of seven. The
// timing runs only in an optimized build; a debug build checks on 10³ points that both sides
// agree.

import GrafluentCollectionsTestSupport
import SpatialTrees
import Testing

@Suite("KDTree nearest neighbours against brute force")
struct KDTreeRatioTests {
    @Test("KDTree: nearestIndex(to:) over 10⁵ points is at least 100× faster than a scan", .timeLimit(.minutes(1)))
    func nearestBeatsScan() async {
        await Task {
            #if DEBUG
            let n = 1_000
            #else
            let n = 100_000
            #endif
            var rng = SeededRandomNumberGenerator(seed: 19)
            let points: [SIMD2<Double>] = (0 ..< n).map { _ in [Double.random(in: 0 ..< 1, using: &rng), Double.random(in: 0 ..< 1, using: &rng)] }
            let queries: [SIMD2<Double>] = (0 ..< 1_000).map { _ in [Double.random(in: 0 ..< 1, using: &rng), Double.random(in: 0 ..< 1, using: &rng)] }
            let tree = KDTree(points)

            func library() -> Int {
                var sink = 0
                for query in queries {
                    sink &+= tree.nearestIndex(to: query) ?? 0
                }
                return sink
            }
            func scan() -> Int {
                points.withUnsafeBufferPointer { points in
                    var sink = 0
                    for query in queries {
                        var best = Double.infinity, bestIndex = 0
                        for k in points.indices {
                            let d = points[k] - query
                            let distance = (d * d).sum()
                            if distance < best {
                                best = distance
                                bestIndex = k
                            }
                        }
                        sink &+= bestIndex
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
            #expect(speedup > 100, "nearestIndex(to:) was only \(speedup)× faster than a scan")
            #endif
        }.value
    }
}
