// A treap's height is that of a random binary search tree: 4.311 ln n − 1.953 ln ln n expected
// (Reed, 2003), with O(1) variance: below 3 log₂ n, which is 4.328 ln n. On 10⁵ elements the
// bound is 49.8 and the seeded treaps here measure 40 to 43. Built from a sequence, grown by random insertions and then thinned by removals, each treap
// stays under it. The large input runs only in an optimized build; a debug build checks the same
// bound on 10³ elements.

import BinarySearchTrees
import Foundation
import GrafluentCollectionsTestSupport
import Testing

@Suite("Treap depth")
struct TreapDepthTests {
    @Test("A treap of 10⁵ elements stays under 3 log₂ n high, however it was built", .timeLimit(.minutes(1)))
    func heightStaysLogarithmic() async {
        await Task {
            #if DEBUG
            let n = 1_000
            #else
            let n = 100_000
            #endif
            let bound = 3 * log2(Double(n))
            var rng = SeededRandomNumberGenerator(seed: 7)

            let built = Treap(0 ..< n, using: &rng)
            #expect(Double(built.height) < bound, "built: height \(built.height), bound \(bound)")

            var inserted = Treap<Int>(using: &rng)
            for element in (0 ..< n).shuffled(using: &rng) {
                inserted.insert(element)
            }
            #expect(Double(inserted.height) < bound, "inserted: height \(inserted.height), bound \(bound)")

            var ascending = Treap<Int>(using: &rng)
            for element in 0 ..< n {
                ascending.insert(element)
            }
            #expect(Double(ascending.height) < bound, "ascending: height \(ascending.height), bound \(bound)")

            var thinned = Treap(0 ..< 2 * n, using: &rng)
            for element in stride(from: 0, to: 2 * n, by: 2) {
                thinned.remove(element)
            }
            #expect(thinned.count == n)
            #expect(Double(thinned.height) < bound, "thinned: height \(thinned.height), bound \(bound)")
        }.value
    }
}
