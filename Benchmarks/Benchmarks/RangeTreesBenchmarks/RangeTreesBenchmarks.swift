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

    // Range queries over query / 2 ..< query, as FenwickTree.sum(in:) above.
    enum AddToSum: MonoidAction {
        typealias Values = Sum<Int>
        static var identity: Int { 0 }
        static func compose(_ outer: Int, _ inner: Int) -> Int { outer &+ inner }
        static func apply(_ update: Int, to sum: Int, count: Int) -> Int { sum &+ update &* count }
    }

    Benchmark("RangeTrees: BASELINE linear-scan range sums") { benchmark in
        for _ in benchmark.scaledIterations {
            values.withUnsafeBufferPointer { values in
                for query in queries {
                    var sum = 0
                    for k in query / 2 ..< query {
                        sum &+= values[k]
                    }
                    blackHole(sum)
                }
            }
        }
    }

    Benchmark("RangeTrees: BASELINE linear-scan range minima") { benchmark in
        for _ in benchmark.scaledIterations {
            values.withUnsafeBufferPointer { values in
                for query in queries {
                    var minimum = Int.max
                    for k in query / 2 ..< query {
                        minimum = Swift.min(minimum, values[k])
                    }
                    blackHole(minimum)
                }
            }
        }
    }

    Benchmark("RangeTrees: BASELINE loop adding to every value in a range") { benchmark in
        var array = values
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            array.withUnsafeMutableBufferPointer { array in
                for update in updates {
                    for k in update.index / 2 ..< update.index {
                        array[k] &+= update.amount
                    }
                }
            }
        }
        blackHole(array)
    }

    Benchmark("RangeTrees: SegmentTree.init(_:)") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(SegmentTree<Sum<Int>>(values))
        }
    }

    Benchmark("RangeTrees: SegmentTree<Sum<Int>>.combined(in:)") { benchmark in
        let tree = SegmentTree<Sum<Int>>(values)
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            for query in queries {
                blackHole(tree.combined(in: query / 2 ..< query))
            }
        }
    }

    Benchmark("RangeTrees: SegmentTree<Minimum<Int>>.combined(in:)") { benchmark in
        let tree = SegmentTree<Minimum<Int>>(values)
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            for query in queries {
                blackHole(tree.combined(in: query / 2 ..< query))
            }
        }
    }

    Benchmark("RangeTrees: SegmentTree.update(at:to:)") { benchmark in
        var tree = SegmentTree<Sum<Int>>(values)
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            for update in updates {
                tree.update(at: update.index, to: update.amount)
            }
        }
        blackHole(tree)
    }

    Benchmark("RangeTrees: LazySegmentTree.apply(_:in:)") { benchmark in
        var tree = LazySegmentTree<AddToSum>(values)
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            for update in updates {
                tree.apply(update.amount, in: update.index / 2 ..< update.index)
            }
        }
        blackHole(tree)
    }

    Benchmark("RangeTrees: LazySegmentTree.combined(in:)") { benchmark in
        var tree = LazySegmentTree<AddToSum>(values)
        for update in updates {
            tree.apply(update.amount, in: update.index / 2 ..< update.index)
        }
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            for query in queries {
                blackHole(tree.combined(in: query / 2 ..< query))
            }
        }
    }

    // 10⁵ intervals of length 1 to 100 over 0 ..< 10⁶, and 1,000 stabbing points.
    let intervals = (0 ..< n).map { k -> IntervalTree<Int, Int>.Entry in
        let lower = next(below: 1_000_000)
        return .init(range: lower ..< lower + 1 + next(below: 100), value: k)
    }
    let points = (0 ..< 1_000).map { _ in next(below: 1_000_000) }

    // The hand-written form: a linear filter over the intervals per point.
    Benchmark("RangeTrees: BASELINE linear filter of intervals containing a point") { benchmark in
        let ranges = intervals.map(\.range)
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            for point in points {
                var found = 0
                for range in ranges where range.lowerBound <= point && point < range.upperBound {
                    found &+= 1
                }
                blackHole(found)
            }
        }
    }

    Benchmark("RangeTrees: IntervalTree.init(_:)") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(IntervalTree(intervals))
        }
    }

    Benchmark("RangeTrees: IntervalTree.insert(_:value:)") { benchmark in
        for _ in benchmark.scaledIterations {
            var tree = IntervalTree<Int, Int>()
            for entry in intervals {
                tree.insert(entry.range, value: entry.value)
            }
            blackHole(tree)
        }
    }

    Benchmark("RangeTrees: IntervalTree.containing(_:)") { benchmark in
        let tree = IntervalTree(intervals)
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            for point in points {
                var found = 0
                for _ in tree.containing(point) {
                    found &+= 1
                }
                blackHole(found)
            }
        }
    }

    Benchmark("RangeTrees: IntervalTree.overlapping(_:)") { benchmark in
        let tree = IntervalTree(intervals)
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            for point in points {
                var found = 0
                for _ in tree.overlapping(point ..< point + 1_000) {
                    found &+= 1
                }
                blackHole(found)
            }
        }
    }
}
