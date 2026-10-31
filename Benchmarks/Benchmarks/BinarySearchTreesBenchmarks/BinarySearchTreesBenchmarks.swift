import Benchmark
import BinarySearchTrees

let benchmarks: @Sendable () -> Void = {
    Benchmark.defaultConfiguration.metrics = [.wallClock, .mallocCountTotal, .instructions]
    Benchmark.defaultConfiguration.maxDuration = .seconds(2)

    // A seeded linear congruential generator, so every run sees the same keys.
    var state: UInt64 = 1
    func next(below bound: Int) -> Int {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Int(truncatingIfNeeded: state >> 33) % bound
    }
    let n = 100_000
    let keys = (0 ..< n).map { _ in next(below: 4 * n) }
    let probes = (0 ..< 10_000).map { _ in next(below: 4 * n) }
    let sorted = Array(Set(keys)).sorted()

    // The hand-written forms the library must keep pace with.
    Benchmark("BinarySearchTrees: BASELINE binary search in a sorted array") { benchmark in
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

    Benchmark("BinarySearchTrees: BASELINE Array(Set(keys)).sorted()") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(Array(Set(keys)).sorted())
        }
    }

    Benchmark("BinarySearchTrees: BASELINE sorted array iteration") { benchmark in
        for _ in benchmark.scaledIterations {
            var sum = 0
            for key in sorted {
                sum &+= key
            }
            blackHole(sum)
        }
    }

    Benchmark("BinarySearchTrees: AVLTree.init(_:)") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(AVLTree(keys))
        }
    }

    Benchmark("BinarySearchTrees: AVLTree.contains(_:)") { benchmark in
        let tree = AVLTree(keys)
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            var found = 0
            for probe in probes where tree.contains(probe) {
                found &+= 1
            }
            blackHole(found)
        }
    }

    Benchmark("BinarySearchTrees: AVLTree.insert(_:) one at a time") { benchmark in
        for _ in benchmark.scaledIterations {
            var tree = AVLTree<Int>()
            for key in keys {
                tree.insert(key)
            }
            blackHole(tree)
        }
    }

    Benchmark("BinarySearchTrees: AVLTree.remove(_:) then insert(_:)") { benchmark in
        var tree = AVLTree(keys)
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            for probe in probes {
                if tree.remove(probe) != nil {
                    tree.insert(probe)
                } else {
                    tree.insert(probe)
                    tree.remove(probe)
                }
            }
        }
        blackHole(tree)
    }

    Benchmark("BinarySearchTrees: AVLTree iteration") { benchmark in
        let tree = AVLTree(keys)
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            var sum = 0
            for key in tree {
                sum &+= key
            }
            blackHole(sum)
        }
    }

    Benchmark("BinarySearchTrees: AVLDictionary subscript stores one at a time") { benchmark in
        for _ in benchmark.scaledIterations {
            var dictionary = AVLDictionary<Int, Int>()
            for key in keys {
                dictionary[key, default: 0] += 1
            }
            blackHole(dictionary)
        }
    }
}
