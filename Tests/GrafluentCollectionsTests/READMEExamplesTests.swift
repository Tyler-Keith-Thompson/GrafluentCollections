// The README's examples, verbatim, so the README cannot drift from the code.

import GrafluentCollections
import Testing
import Trees

@Suite("README examples")
struct READMEExamplesTests {
    @Test("Usage: prefix sums, range sums, an add and a lower bound")
    func usage() {
        var scores: FenwickTree = [3, 1, 4, 1, 5, 9, 2, 6]
        let first: Int = 9
        let range: Int = 19
        let afterAdd: Int = 19
        let lowerBound: Int = 2
        #expect(scores.prefixSum(through: 3) == first)
        #expect(scores.sum(in: 2 ..< 6) == range)
        scores.add(10, at: 1)
        #expect(scores.prefixSum(through: 3) == afterAdd)
        #expect(scores.lowerBound(ofPrefixSum: 15) == lowerBound)
    }

    @Test("Usage: the update tree as an Arborescence")
    func arborescence() {
        let updates = Arborescence(FenwickTree([1, 2, 3, 4, 5, 6, 7, 8]))
        let root: Int = 8
        let parent: Int = 3
        #expect(updates.root == root)
        #expect(updates.parent(of: 2)! == parent)
    }
}
