// Accessing every element of a splay tree in ascending order costs O(n) in all (the sequential
// access theorem; Tarjan, 1985), while n accesses at random keys cost O(n log n). On 10⁶ elements
// a random shape descends about forty levels per random access, so the ascending pass should be
// several times faster: about 13× on a laptop, bounded here at 4×. Both passes start
// from copies of the same tree, built by seeded random insertions, and each keeps its fastest of
// five rounds. The timing runs only in an optimized build; a debug build checks on 10³ elements
// that both passes find every element.

import BinarySearchTrees
import Generators
import GrafluentCollectionsTestSupport
import Sampling
import Testing

@Suite("Splay tree sequential access")
struct SplayTreeSequentialAccessTests {
    @Test("Accessing 10⁶ elements in ascending order is at least 4× faster than at random", .timeLimit(.minutes(2)))
    func sequentialAccessIsLinear() async {
        await Task {
            #if DEBUG
            let n = 1_000
            #else
            let n = 1_000_000
            #endif
            var rng = Xoshiro256StarStar(seed: 8)
            var tree = SplayTree<Int>()
            var order = Array(0 ..< n)
            // Fisher–Yates over integer(in:): SwiftPRNG has no shuffle, and the standard library's
            // shuffle may change its order between Swift releases.
            for i in stride(from: order.count - 1, to: 0, by: -1) { order.swapAt(i, rng.integer(in: 0 ... i)) }
            for element in order {
                tree.insert(element)
            }
            let randomKeys = (0 ..< n).map { _ in rng.integer(in: 0 ..< n) }

            func ascending(_ tree: SplayTree<Int>) -> Int {
                var tree = tree
                var found = 0
                for element in 0 ..< n where tree.access(element) != nil {
                    found &+= 1
                }
                return found
            }
            func random(_ tree: SplayTree<Int>) -> Int {
                var tree = tree
                var found = 0
                for element in randomKeys where tree.access(element) != nil {
                    found &+= 1
                }
                return found
            }
            #expect(ascending(tree) == n)
            #expect(random(tree) == n)

            #if !DEBUG
            let clock = ContinuousClock()
            var sequential = Duration.seconds(1_000), scattered = Duration.seconds(1_000)
            for _ in 0 ..< 5 {
                sequential = min(sequential, clock.measure { _ = ascending(tree) })
                scattered = min(scattered, clock.measure { _ = random(tree) })
            }
            let ratio = scattered / sequential
            #expect(ratio >= 4, "ascending \(sequential), random \(scattered)")
            #endif
        }.value
    }
}
