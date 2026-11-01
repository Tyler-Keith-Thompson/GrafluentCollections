import Benchmark
import BenchmarkWorkloads
import BinarySearchTrees
import BitCollections
import BTrees
import HashTreeCollections
import PersistentTrees
import SkipLists

// The same seven workloads over every set-shaped structure of the library, a sorted array
// written by hand (the BASELINE), the standard library's Set, and swift-collections' TreeSet
// (a persistent hash tree) and BitSet (a sorted bitmap of small integers). The sets hold 10⁴
// keys, small enough that the whole target simulates in minutes.

let benchmarks: @Sendable () -> Void = {
    Benchmark.defaultConfiguration.metrics = [.wallClock, .mallocCountTotal, .instructions]
    Benchmark.defaultConfiguration.maxDuration = .seconds(2)

    let workload = IntegerWorkload(count: 10_000, seed: 24)
    // The treap's priorities and the skip list's tower heights come from a seeded generator too,
    // so their shapes, and their counts, are the same on every run.
    var generator = SplitMix64(seed: 25)

    registerSortedArray(workload)
    register("AVLTree", AVLTree<Int>(), workload)
    register("RedBlackTree", RedBlackTree<Int>(), workload)
    register("Treap", Treap<Int>(using: &generator), workload)
    register("SplayTree", SplayTree<Int>(), workload)
    register("BTree", BTree<Int>(), workload)
    register("SkipList", SkipList<Int>(using: &generator), workload)
    register("PersistentTreeSet", PersistentTreeSet<Int>(), workload)
    register("Set", Set<Int>(), workload)
    register("TreeSet", TreeSet<Int>(), workload)
    register("BitSet", BitSet(), workload)
}

/// The seven workloads for one kind of set, starting from `empty`.
func register<S: SetAlgebra & Sequence>(_ name: String, _ empty: S, _ workload: IntegerWorkload) where S.Element == Int {
    let keys = workload.keys, ascending = workload.ascending, misses = workload.misses
    var full = empty
    for key in keys {
        full.insert(key)
    }
    let built = full

    Benchmark("SetComparisons: \(name) insert ascending") { benchmark in
        for _ in benchmark.scaledIterations {
            var set = empty
            for key in ascending {
                set.insert(key)
            }
            blackHole(set)
        }
    }

    Benchmark("SetComparisons: \(name) insert random") { benchmark in
        for _ in benchmark.scaledIterations {
            var set = empty
            for key in keys {
                set.insert(key)
            }
            blackHole(set)
        }
    }

    Benchmark("SetComparisons: \(name) lookup hit") { benchmark in
        for _ in benchmark.scaledIterations {
            var found = 0
            for key in keys where built.contains(key) {
                found &+= 1
            }
            blackHole(found)
        }
    }

    Benchmark("SetComparisons: \(name) lookup miss") { benchmark in
        for _ in benchmark.scaledIterations {
            var found = 0
            for key in misses where built.contains(key) {
                found &+= 1
            }
            blackHole(found)
        }
    }

    Benchmark("SetComparisons: \(name) iterate") { benchmark in
        for _ in benchmark.scaledIterations {
            var sum = 0
            for key in built {
                sum &+= key
            }
            blackHole(sum)
        }
    }

    Benchmark("SetComparisons: \(name) remove then insert") { benchmark in
        var set = built
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            for key in keys {
                set.remove(key)
                set.insert(key)
            }
        }
        blackHole(set)
    }

    Benchmark("SetComparisons: \(name) copy then insert, 100 copies") { benchmark in
        for _ in benchmark.scaledIterations {
            for k in 0 ..< 100 {
                var copy = built
                copy.insert(misses[k])
                blackHole(copy)
            }
        }
    }
}

/// The seven workloads for a sorted array kept by binary search, written by hand.
func registerSortedArray(_ workload: IntegerWorkload) {
    let keys = workload.keys, ascending = workload.ascending, misses = workload.misses
    let built = workload.ascending

    func lowerBound(_ array: [Int], _ key: Int) -> Int {
        array.withUnsafeBufferPointer { array in
            var low = 0
            var high = array.count
            while low < high {
                let middle = low &+ (high &- low) / 2
                if array[middle] < key {
                    low = middle &+ 1
                } else {
                    high = middle
                }
            }
            return low
        }
    }
    func insert(_ key: Int, into array: inout [Int]) {
        let position = lowerBound(array, key)
        if position == array.count || array[position] != key {
            array.insert(key, at: position)
        }
    }

    Benchmark("SetComparisons: BASELINE sorted array insert ascending") { benchmark in
        for _ in benchmark.scaledIterations {
            var array: [Int] = []
            for key in ascending {
                insert(key, into: &array)
            }
            blackHole(array)
        }
    }

    Benchmark("SetComparisons: BASELINE sorted array insert random") { benchmark in
        for _ in benchmark.scaledIterations {
            var array: [Int] = []
            for key in keys {
                insert(key, into: &array)
            }
            blackHole(array)
        }
    }

    Benchmark("SetComparisons: BASELINE sorted array lookup hit") { benchmark in
        for _ in benchmark.scaledIterations {
            var found = 0
            for key in keys {
                let position = lowerBound(built, key)
                if position < built.count && built[position] == key { found &+= 1 }
            }
            blackHole(found)
        }
    }

    Benchmark("SetComparisons: BASELINE sorted array lookup miss") { benchmark in
        for _ in benchmark.scaledIterations {
            var found = 0
            for key in misses {
                let position = lowerBound(built, key)
                if position < built.count && built[position] == key { found &+= 1 }
            }
            blackHole(found)
        }
    }

    Benchmark("SetComparisons: BASELINE sorted array iterate") { benchmark in
        for _ in benchmark.scaledIterations {
            var sum = 0
            for key in built {
                sum &+= key
            }
            blackHole(sum)
        }
    }

    Benchmark("SetComparisons: BASELINE sorted array remove then insert") { benchmark in
        var array = built
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            for key in keys {
                array.remove(at: lowerBound(array, key))
                insert(key, into: &array)
            }
        }
        blackHole(array)
    }

    Benchmark("SetComparisons: BASELINE sorted array copy then insert, 100 copies") { benchmark in
        for _ in benchmark.scaledIterations {
            for k in 0 ..< 100 {
                var copy = built
                insert(misses[k], into: &copy)
                blackHole(copy)
            }
        }
    }
}
