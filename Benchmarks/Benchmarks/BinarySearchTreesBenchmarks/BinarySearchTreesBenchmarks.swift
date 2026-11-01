import Benchmark
import BinarySearchTrees
import Trees

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

    // The floor for converting a tree's shape: Grafluent's own build from ready child tables,
    // here a complete binary tree on as many vertices as the AVL tree holds.
    Benchmark("BinarySearchTrees: BASELINE BinaryTree(left:right:) from child tables") { benchmark in
        let count = sorted.count
        let left: [Int?] = (0 ..< count).map { 2 * $0 + 1 < count ? 2 * $0 + 1 : nil }
        let right: [Int?] = (0 ..< count).map { 2 * $0 + 2 < count ? 2 * $0 + 2 : nil }
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            blackHole(BinaryTree(left: left, right: right))
        }
    }

    Benchmark("BinarySearchTrees: BinaryTree(_:) of an AVLTree") { benchmark in
        let tree = AVLTree(keys)
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            blackHole(BinaryTree(tree))
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

    Benchmark("BinarySearchTrees: RedBlackTree.init(_:)") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(RedBlackTree(keys))
        }
    }

    Benchmark("BinarySearchTrees: RedBlackTree.contains(_:)") { benchmark in
        let tree = RedBlackTree(keys)
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            var found = 0
            for probe in probes where tree.contains(probe) {
                found &+= 1
            }
            blackHole(found)
        }
    }

    Benchmark("BinarySearchTrees: RedBlackTree.insert(_:) one at a time") { benchmark in
        for _ in benchmark.scaledIterations {
            var tree = RedBlackTree<Int>()
            for key in keys {
                tree.insert(key)
            }
            blackHole(tree)
        }
    }

    Benchmark("BinarySearchTrees: RedBlackTree.remove(_:) then insert(_:)") { benchmark in
        var tree = RedBlackTree(keys)
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

    Benchmark("BinarySearchTrees: RedBlackTree iteration") { benchmark in
        let tree = RedBlackTree(keys)
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            var sum = 0
            for key in tree {
                sum &+= key
            }
            blackHole(sum)
        }
    }

    // Two halves of the keys, for the set operations, and a seeded generator for the treaps'
    // priorities.
    let firstHalf = Array(keys[..<(n / 2)])
    let secondHalf = Array(keys[(n / 2)...])
    let firstSet = Set(firstHalf)
    let secondSet = Set(secondHalf)
    struct LinearCongruential: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return state
        }
    }

    Benchmark("BinarySearchTrees: BASELINE Array(Set.union(_:)).sorted()") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(Array(firstSet.union(secondSet)).sorted())
        }
    }

    Benchmark("BinarySearchTrees: Treap.union(_:)") { benchmark in
        var generator = LinearCongruential(state: 2)
        let first = Treap(firstHalf, using: &generator)
        let second = Treap(secondHalf, using: &generator)
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            blackHole(first.union(second))
        }
    }

    Benchmark("BinarySearchTrees: Treap.init(_:)") { benchmark in
        var generator = LinearCongruential(state: 3)
        for _ in benchmark.scaledIterations {
            blackHole(Treap(keys, using: &generator))
        }
    }

    Benchmark("BinarySearchTrees: Treap.contains(_:)") { benchmark in
        var generator = LinearCongruential(state: 4)
        let tree = Treap(keys, using: &generator)
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            var found = 0
            for probe in probes where tree.contains(probe) {
                found &+= 1
            }
            blackHole(found)
        }
    }

    Benchmark("BinarySearchTrees: Treap.insert(_:) one at a time") { benchmark in
        var generator = LinearCongruential(state: 5)
        for _ in benchmark.scaledIterations {
            var tree = Treap<Int>(using: &generator)
            for key in keys {
                tree.insert(key)
            }
            blackHole(tree)
        }
    }

    Benchmark("BinarySearchTrees: Treap.remove(_:) then insert(_:)") { benchmark in
        var generator = LinearCongruential(state: 6)
        var tree = Treap(keys, using: &generator)
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

    Benchmark("BinarySearchTrees: Treap.split(at:) then join(_:)") { benchmark in
        var generator = LinearCongruential(state: 7)
        var tree = Treap(keys, using: &generator)
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            for probe in probes.prefix(100) {
                var parts = tree.split(at: probe)
                try? parts.lower.join(parts.upper)
                tree = parts.lower
            }
        }
        blackHole(tree)
    }

    // Skewed lookups: 10⁴ probes drawn from a Zipf distribution (exponent 1) over the sorted
    // keys, so a few keys take most of the probes.
    let zipfProbes: [Int] = {
        var cumulative: [Double] = []
        cumulative.reserveCapacity(sorted.count)
        var total = 0.0
        for rank in 1 ... sorted.count {
            total += 1 / Double(rank)
            cumulative.append(total)
        }
        // Rank r goes to a scattered key, so the popular keys aren't neighbours.
        let stride = 7_919 % sorted.count
        return (0 ..< 10_000).map { _ in
            let target = Double(next(below: 1 << 30)) / Double(1 << 30) * total
            var low = 0
            var high = cumulative.count - 1
            while low < high {
                let middle = (low + high) / 2
                if cumulative[middle] < target { low = middle + 1 } else { high = middle }
            }
            return sorted[(low * stride) % sorted.count]
        }
    }()
    let lookupTable = Dictionary(uniqueKeysWithValues: sorted.map { ($0, ()) })

    Benchmark("BinarySearchTrees: BASELINE Dictionary lookups, Zipf-skewed") { benchmark in
        for _ in benchmark.scaledIterations {
            var found = 0
            for probe in zipfProbes where lookupTable[probe] != nil {
                found &+= 1
            }
            blackHole(found)
        }
    }

    Benchmark("BinarySearchTrees: AVLTree.contains(_:), Zipf-skewed") { benchmark in
        let tree = AVLTree(keys)
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            var found = 0
            for probe in zipfProbes where tree.contains(probe) {
                found &+= 1
            }
            blackHole(found)
        }
    }

    Benchmark("BinarySearchTrees: SplayTree.access(_:), Zipf-skewed") { benchmark in
        var tree = SplayTree(keys)
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            var found = 0
            for probe in zipfProbes where tree.access(probe) != nil {
                found &+= 1
            }
            blackHole(found)
        }
        blackHole(tree)
    }

    Benchmark("BinarySearchTrees: SplayTree.init(_:)") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(SplayTree(keys))
        }
    }

    Benchmark("BinarySearchTrees: SplayTree.insert(_:) one at a time") { benchmark in
        for _ in benchmark.scaledIterations {
            var tree = SplayTree<Int>()
            for key in keys {
                tree.insert(key)
            }
            blackHole(tree)
        }
    }

    Benchmark("BinarySearchTrees: SplayTree.remove(_:) then insert(_:)") { benchmark in
        var tree = SplayTree(keys)
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

    Benchmark("BinarySearchTrees: SplayTree.access(_:) in ascending order") { benchmark in
        var tree = SplayTree(keys)
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            var found = 0
            for key in sorted where tree.access(key) != nil {
                found &+= 1
            }
            blackHole(found)
        }
        blackHole(tree)
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
