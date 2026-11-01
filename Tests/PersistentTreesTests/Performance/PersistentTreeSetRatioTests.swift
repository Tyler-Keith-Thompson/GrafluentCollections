// Keeping every version of an insertion history: 10⁴ seeded random insertions into a
// PersistentTreeSet, keeping each version, against copying an AVLTree before each insertion so
// that the earlier versions survive. The copies cost O(n) each, O(n²) in all, and the persistent
// versions O(log n) new vertices each, so the persistent set must be at least 5× faster; the
// gap measured on a laptop is about 15×, so the bound leaves room for a busy machine. The
// two sides are timed in alternating rounds, each keeping its fastest of five. The timing runs
// only in an optimized build; a debug build checks on 500 insertions that both sides agree.

import BinarySearchTrees
import GrafluentCollectionsTestSupport
import PersistentTrees
import Testing

@Suite("Persistent versions against copied AVL trees")
struct PersistentTreeSetRatioTests {
    @Test("PersistentTreeSet: keeping 10⁴ versions is at least 5× faster than copying an AVLTree", .timeLimit(.minutes(1)))
    func versionsBeatCopies() async {
        await Task {
            #if DEBUG
            let n = 500
            #else
            let n = 10_000
            #endif
            var rng = SeededRandomNumberGenerator(seed: 22)
            let values = (0 ..< n).map { _ in Int.random(in: 0 ..< 1_000_000_000, using: &rng) }

            func library() -> [PersistentTreeSet<Int>] {
                var versions: [PersistentTreeSet<Int>] = [PersistentTreeSet()]
                versions.reserveCapacity(n + 1)
                for value in values {
                    versions.append(versions[versions.count - 1].inserting(value))
                }
                return versions
            }
            func copies() -> [AVLTree<Int>] {
                var versions: [AVLTree<Int>] = [AVLTree()]
                versions.reserveCapacity(n + 1)
                for value in values {
                    var next = versions[versions.count - 1]
                    next.insert(value)
                    versions.append(next)
                }
                return versions
            }
            let persistent = library(), copied = copies()
            for k in Swift.stride(from: 0, through: n, by: n / 10) {
                #expect(Array(persistent[k]) == Array(copied[k]))
            }

            #if !DEBUG
            let clock = ContinuousClock()
            var libraryTime = Duration.seconds(1_000), baselineTime = Duration.seconds(1_000)
            var sink = 0
            for _ in 0 ..< 5 {
                libraryTime = min(libraryTime, clock.measure { sink &+= library().count })
                baselineTime = min(baselineTime, clock.measure { sink &+= copies().count })
            }
            #expect(sink != 1)
            let speedup = baselineTime / libraryTime
            #expect(speedup > 5, "Keeping versions was only \(speedup)× faster than copying")
            #endif
        }.value
    }
}
