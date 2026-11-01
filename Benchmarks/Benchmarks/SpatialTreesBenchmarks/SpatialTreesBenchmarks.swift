import Benchmark
import SpatialTrees

let benchmarks: @Sendable () -> Void = {
    Benchmark.defaultConfiguration.metrics = [.wallClock, .mallocCountTotal, .instructions]
    Benchmark.defaultConfiguration.maxDuration = .seconds(2)

    // A seeded linear congruential generator, so every run sees the same points and queries.
    var state: UInt64 = 18
    func next() -> Double {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Double(state >> 11) / Double(1 << 53)
    }
    let small = (0 ..< 100_000).map { _ in SIMD2<Double>(next(), next()) }
    let large = (0 ..< 1_000_000).map { _ in SIMD2<Double>(next(), next()) }
    let queries = (0 ..< 1_000).map { _ in SIMD2<Double>(next(), next()) }
    let manyQueries = (0 ..< 10_000).map { _ in SIMD2<Double>(next(), next()) }

    // The hand-written form: the distance to every point, per query.
    Benchmark("SpatialTrees: BASELINE brute-force nearest of 10⁵ points") { benchmark in
        for _ in benchmark.scaledIterations {
            small.withUnsafeBufferPointer { points in
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
                    blackHole(bestIndex)
                }
            }
        }
    }

    Benchmark("SpatialTrees: KDTree nearestIndex(to:) of 10⁵ points") { benchmark in
        let tree = KDTree(small)
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            for query in queries {
                blackHole(tree.nearestIndex(to: query))
            }
        }
    }

    Benchmark("SpatialTrees: KDTree.init(_:) of 10⁶ points") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(KDTree(large))
        }
    }

    Benchmark("SpatialTrees: KDTree nearestIndex(to:) of 10⁶ points, 10⁴ queries") { benchmark in
        let tree = KDTree(large)
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            for query in manyQueries {
                blackHole(tree.nearestIndex(to: query))
            }
        }
    }

    Benchmark("SpatialTrees: KDTree nearestIndices(to:count: 10) of 10⁶ points") { benchmark in
        let tree = KDTree(large)
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            for query in queries {
                blackHole(tree.nearestIndices(to: query, count: 10))
            }
        }
    }

    Benchmark("SpatialTrees: KDTree indices(within:of:) of 10⁶ points") { benchmark in
        let tree = KDTree(large)
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            for query in queries {
                blackHole(tree.indices(within: 0.005, of: query))
            }
        }
    }

    // Boxes 0.01 on a side: about ten of the 10⁵ points each, a hundred of the 10⁶.
    let boxes = queries.map { BoundingBox(lower: $0, upper: $0 + [0.01, 0.01]) }
    let manyBoxes = manyQueries.map { BoundingBox(lower: $0, upper: $0 + [0.01, 0.01]) }
    let unit = BoundingBox<SIMD2<Double>>(lower: [0, 0], upper: [1, 1])

    // The hand-written form: every point tested against every box.
    Benchmark("SpatialTrees: BASELINE brute-force box queries of 10⁵ points") { benchmark in
        for _ in benchmark.scaledIterations {
            small.withUnsafeBufferPointer { points in
                for box in boxes {
                    var found = 0
                    for point in points where box.contains(point) {
                        found &+= 1
                    }
                    blackHole(found)
                }
            }
        }
    }

    Benchmark("SpatialTrees: Quadtree items(in:) of 10⁵ points") { benchmark in
        var tree = Quadtree<Int>(bounds: unit)
        for (k, point) in small.enumerated() {
            tree.insert(k, at: point)
        }
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            for box in boxes {
                blackHole(tree.items(in: box))
            }
        }
    }

    Benchmark("SpatialTrees: KDTree indices(in:) of 10⁵ points") { benchmark in
        let tree = KDTree(small)
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            for box in boxes {
                blackHole(tree.indices(in: box))
            }
        }
    }

    Benchmark("SpatialTrees: Quadtree insert(_:at:) of 10⁶ points") { benchmark in
        for _ in benchmark.scaledIterations {
            var tree = Quadtree<Int>(bounds: unit)
            for (k, point) in large.enumerated() {
                tree.insert(k, at: point)
            }
            blackHole(tree)
        }
    }

    Benchmark("SpatialTrees: Quadtree items(in:) of 10⁶ points, 10⁴ queries") { benchmark in
        var tree = Quadtree<Int>(bounds: unit)
        for (k, point) in large.enumerated() {
            tree.insert(k, at: point)
        }
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            for box in manyBoxes {
                blackHole(tree.items(in: box))
            }
        }
    }

    Benchmark("SpatialTrees: Quadtree nearest(to:) of 10⁶ points") { benchmark in
        var tree = Quadtree<Int>(bounds: unit)
        for (k, point) in large.enumerated() {
            tree.insert(k, at: point)
        }
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            for query in queries {
                blackHole(tree.nearest(to: query))
            }
        }
    }
}
