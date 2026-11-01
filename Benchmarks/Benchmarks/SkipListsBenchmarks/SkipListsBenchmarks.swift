import Benchmark
import BinarySearchTrees
import SkipLists

let benchmarks: @Sendable () -> Void = {
    Benchmark.defaultConfiguration.metrics = [.wallClock, .mallocCountTotal, .instructions]
    Benchmark.defaultConfiguration.maxDuration = .seconds(2)

    // A seeded linear congruential generator, so every run sees the same keys: 10⁶ of them, and
    // 10⁴ probes, about one in four present.
    var state: UInt64 = 1
    func next(below bound: Int) -> Int {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Int(truncatingIfNeeded: state >> 33) % bound
    }
    let n = 1_000_000
    let keys = (0 ..< n).map { _ in next(below: 4 * n) }
    let probes = (0 ..< 10_000).map { _ in next(below: 4 * n) }
    let sorted = Array(Set(keys)).sorted()

    // The hand-written forms the library must keep pace with.
    Benchmark("SkipLists: BASELINE binary search in a sorted array") { benchmark in
        for _ in benchmark.scaledIterations {
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
                blackHole(found)
            }
        }
    }

    Benchmark("SkipLists: BASELINE sorted array iteration") { benchmark in
        for _ in benchmark.scaledIterations {
            var sum = 0
            for key in sorted {
                sum &+= key
            }
            blackHole(sum)
        }
    }

    Benchmark("SkipLists: AVLTree.contains(_:)") { benchmark in
        let list = AVLTree(keys)
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            var found = 0
            for probe in probes where list.contains(probe) {
                found &+= 1
            }
            blackHole(found)
        }
        benchmark.stopMeasurement()
    }

    Benchmark("SkipLists: AVLTree.insert(_:) one at a time") { benchmark in
        for _ in benchmark.scaledIterations {
            var list = AVLTree<Int>()
            for key in keys {
                list.insert(key)
            }
            blackHole(list)
        }
    }

    Benchmark("SkipLists: SkipList.init(_:)") { benchmark in
        var generator = SplitMix64(state: 2)
        for _ in benchmark.scaledIterations {
            blackHole(SkipList(keys, using: &generator))
        }
    }

    Benchmark("SkipLists: SkipList.contains(_:)") { benchmark in
        var generator = SplitMix64(state: 2)
        let list = SkipList(keys, using: &generator)
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            var found = 0
            for probe in probes where list.contains(probe) {
                found &+= 1
            }
            blackHole(found)
        }
        benchmark.stopMeasurement()
    }

    Benchmark("SkipLists: SkipList.insert(_:) one at a time") { benchmark in
        var generator = SplitMix64(state: 2)
        for _ in benchmark.scaledIterations {
            var list = SkipList<Int>(using: &generator)
            for key in keys {
                list.insert(key)
            }
            blackHole(list)
        }
    }

    Benchmark("SkipLists: SkipList.remove(_:) then insert(_:)") { benchmark in
        var generator = SplitMix64(state: 2)
        var list = SkipList(keys, using: &generator)
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            for probe in probes {
                if list.remove(probe) != nil {
                    list.insert(probe)
                } else {
                    list.insert(probe)
                    list.remove(probe)
                }
            }
        }
        benchmark.stopMeasurement()
        blackHole(list)
    }

    Benchmark("SkipLists: SkipList iteration") { benchmark in
        var generator = SplitMix64(state: 2)
        let list = SkipList(keys, using: &generator)
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            var sum = 0
            for key in list {
                sum &+= key
            }
            blackHole(sum)
        }
        benchmark.stopMeasurement()
    }

    Benchmark("SkipLists: SkipList subscript by rank") { benchmark in
        var generator = SplitMix64(state: 2)
        let list = SkipList(keys, using: &generator)
        let ranks = probes.map { $0 % list.count }
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            var sum = 0
            for rank in ranks {
                sum &+= list[rank]
            }
            blackHole(sum)
        }
        benchmark.stopMeasurement()
    }
}

/// SplitMix64, so every run builds the same towers.
struct SplitMix64: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
