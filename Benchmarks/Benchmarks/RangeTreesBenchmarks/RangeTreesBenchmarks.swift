import Benchmark
import RangeTrees

let benchmarks: @Sendable () -> Void = {
    Benchmark.defaultConfiguration.metrics = [.wallClock, .mallocCountTotal, .instructions]
    Benchmark.defaultConfiguration.maxDuration = .seconds(2)

    // A seeded linear congruential generator, so every run sees the same values and queries.
    var state: UInt64 = 15
    func next(below bound: Int) -> Int {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Int(truncatingIfNeeded: state >> 33) % bound
    }
    let n = 100_000
    let values = (0 ..< n).map { _ in next(below: 2_001) - 1_000 }
    let queries = (0 ..< 1_000).map { _ in next(below: n) }
    let updates = (0 ..< 1_000).map { _ in (index: next(below: n), amount: next(below: 2_001) - 1_000) }

    // The hand-written form the library must keep pace with: a linear scan per query.
    Benchmark("RangeTrees: BASELINE linear-scan prefix sums") { benchmark in
        for _ in benchmark.scaledIterations {
            values.withUnsafeBufferPointer { values in
                for query in queries {
                    var sum = 0
                    for k in 0 ... query {
                        sum &+= values[k]
                    }
                    blackHole(sum)
                }
            }
        }
    }

    // A prefix-sum array: O(1) queries, O(n) per update.
    Benchmark("RangeTrees: BASELINE prefix-sum array, queries") { benchmark in
        var prefix = [Int](repeating: 0, count: n)
        var running = 0
        for k in 0 ..< n {
            running &+= values[k]
            prefix[k] = running
        }
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            for query in queries {
                blackHole(prefix[query])
            }
        }
    }

    Benchmark("RangeTrees: BASELINE prefix-sum array, updates") { benchmark in
        var prefix = [Int](repeating: 0, count: n)
        var running = 0
        for k in 0 ..< n {
            running &+= values[k]
            prefix[k] = running
        }
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            prefix.withUnsafeMutableBufferPointer { prefix in
                for update in updates {
                    for k in update.index ..< n {
                        prefix[k] &+= update.amount
                    }
                }
            }
        }
        blackHole(prefix)
    }

    Benchmark("RangeTrees: FenwickTree.init(_:)") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(FenwickTree(values))
        }
    }

    Benchmark("RangeTrees: FenwickTree.prefixSum(through:)") { benchmark in
        let tree = FenwickTree(values)
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            for query in queries {
                blackHole(tree.prefixSum(through: query))
            }
        }
    }

    Benchmark("RangeTrees: FenwickTree.sum(in:)") { benchmark in
        let tree = FenwickTree(values)
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            for query in queries {
                blackHole(tree.sum(in: query / 2 ..< query))
            }
        }
    }

    Benchmark("RangeTrees: FenwickTree.add(_:at:)") { benchmark in
        var tree = FenwickTree(values)
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            for update in updates {
                tree.add(update.amount, at: update.index)
            }
        }
        blackHole(tree)
    }

    Benchmark("RangeTrees: FenwickTree.lowerBound(ofPrefixSum:)") { benchmark in
        let tree = FenwickTree(values.map { $0 + 1_000 })
        let total = tree.prefixSum(through: n - 1)
        let targets = queries.map { $0 * (total / n) }
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            for target in targets {
                blackHole(tree.lowerBound(ofPrefixSum: target))
            }
        }
    }

    Benchmark("RangeTrees: FenwickTree iteration") { benchmark in
        let tree = FenwickTree(values)
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            var sum = 0
            for value in tree {
                sum &+= value
            }
            blackHole(sum)
        }
    }
}
