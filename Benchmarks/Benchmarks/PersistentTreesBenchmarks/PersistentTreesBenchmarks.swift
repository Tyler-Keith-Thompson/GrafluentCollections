import Benchmark
import BinarySearchTrees
import PersistentTrees

let benchmarks: @Sendable () -> Void = {
    Benchmark.defaultConfiguration.metrics = [.wallClock, .mallocCountTotal, .instructions]
    Benchmark.defaultConfiguration.maxDuration = .seconds(2)

    // A seeded linear congruential generator, so every run sees the same values.
    var state: UInt64 = 22
    func next() -> Int {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Int(state >> 34)
    }
    // The copying side is O(n²), so the pair compared is 2×10³ insertions; the persistent side
    // alone also runs the 10⁵ of a long history.
    let few = (0 ..< 2_000).map { _ in next() }
    let many = (0 ..< 100_000).map { _ in next() }
    let left = (0 ..< 100_000).map { _ in next() }
    let right = (0 ..< 100_000).map { _ in next() }
    let leftSet = PersistentTreeSet(left), rightSet = PersistentTreeSet(right)
    let leftHashed = Set(left), rightHashed = Set(right)
    // Two versions that share all but 100 edits each.
    var leftVersion = leftSet, rightVersion = leftSet
    for k in 0 ..< 100 {
        leftVersion = leftVersion.inserting(few[k])
        rightVersion = rightVersion.inserting(few[k + 100])
    }
    let keptLeft = leftVersion, keptRight = rightVersion

    // The hand-written form: copy the tree before each insertion so every version survives.
    Benchmark("PersistentTrees: BASELINE AVLTree copies, 2×10³ insertions keeping every version") { benchmark in
        for _ in benchmark.scaledIterations {
            var versions: [AVLTree<Int>] = [AVLTree()]
            for value in few {
                var version = versions[versions.count - 1]
                version.insert(value)
                versions.append(version)
            }
            blackHole(versions)
        }
    }

    Benchmark("PersistentTrees: PersistentTreeSet, 2×10³ insertions keeping every version") { benchmark in
        for _ in benchmark.scaledIterations {
            var versions: [PersistentTreeSet<Int>] = [PersistentTreeSet()]
            for value in few {
                versions.append(versions[versions.count - 1].inserting(value))
            }
            blackHole(versions)
        }
    }

    Benchmark("PersistentTrees: PersistentTreeSet, 10⁵ insertions keeping every version") { benchmark in
        for _ in benchmark.scaledIterations {
            var versions: [PersistentTreeSet<Int>] = [PersistentTreeSet()]
            versions.reserveCapacity(many.count + 1)
            for value in many {
                versions.append(versions[versions.count - 1].inserting(value))
            }
            blackHole(versions)
        }
    }

    // The hand-written form: hashed union, then sorting to get the order a sorted set keeps.
    Benchmark("PersistentTrees: BASELINE Set.union and sort of two 10⁵ sets") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(leftHashed.union(rightHashed).sorted())
        }
    }

    Benchmark("PersistentTrees: PersistentTreeSet.union of two 10⁵ sets") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(leftSet.union(rightSet))
        }
    }

    Benchmark("PersistentTrees: PersistentTreeSet.union of two 10⁵ versions 100 edits apart") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(keptLeft.union(keptRight))
        }
    }

    Benchmark("PersistentTrees: PersistentTreeSet.contains, 10⁵ lookups in 10⁵") { benchmark in
        for _ in benchmark.scaledIterations {
            var found = 0
            for value in right where leftSet.contains(value) {
                found &+= 1
            }
            blackHole(found)
        }
    }
}
