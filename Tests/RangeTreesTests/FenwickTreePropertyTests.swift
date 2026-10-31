// Property tests against a naive reference: a plain array, summed with `reduce`. Each test is
// self-contained; see FenwickTreeTests.swift.

import GrafluentCollectionsTestSupport
import PropertyBased
import RangeTrees
import Testing

@Suite("FenwickTree: properties")
struct FenwickTreePropertyTests {
    @Test("After any adds, every prefix sum, range sum and value matches the array's", .tags(.randomized))
    func matchesArray() async {
        let values = Gen.int(in: -1_000 ... 1_000).array(of: 0 ... 40)
        let operations = zip(Gen.int(in: 0 ... 1_000), Gen.int(in: -1_000 ... 1_000)).array(of: 0 ... 30)
        await propertyCheck(count: 300, input: values, operations) { values, operations in
            var reference = values
            var tree = FenwickTree(values)
            for (position, amount) in operations where !reference.isEmpty {
                let index = position % reference.count
                reference[index] += amount
                tree.add(amount, at: index)
            }
            #expect(Array(tree) == reference)
            #expect(tree.count == reference.count)
            for index in reference.indices {
                #expect(tree.prefixSum(through: index) == reference[...index].reduce(0, +))
            }
            for lower in 0 ... reference.count {
                for upper in lower ... reference.count {
                    #expect(tree.sum(in: lower ..< upper) == reference[lower ..< upper].reduce(0, +))
                }
            }
            #expect(tree == FenwickTree(reference))
        }
    }

    @Test("lowerBound(ofPrefixSum:) is the first index whose running sum reaches the value, over non-negative values", .tags(.randomized))
    func lowerBoundMatchesScan() async {
        let values = Gen.int(in: 0 ... 20).array(of: 0 ... 40)
        let targets = Gen.int(in: -5 ... 900).array(of: 1 ... 20)
        await propertyCheck(count: 300, input: values, targets) { values, targets in
            let tree = FenwickTree(values)
            for target in targets {
                var running = 0
                var expected = values.count
                for (index, value) in values.enumerated() {
                    running += value
                    if running >= target {
                        expected = index
                        break
                    }
                }
                #expect(tree.lowerBound(ofPrefixSum: target) == expected, "target \(target)")
            }
        }
    }

    @Test("The linear build gives the same tree as adding each value to zeros", .tags(.randomized))
    func buildMatchesAdds() {
        var rng = SeededRandomNumberGenerator(seed: 15)
        for count in 0 ... 70 {
            let values = (0 ..< count).map { _ in Int.random(in: -100 ... 100, using: &rng) }
            var added = FenwickTree([Int](repeating: 0, count: count))
            for (index, value) in values.enumerated() {
                added.add(value, at: index)
            }
            let built = FenwickTree(values)
            #expect(built == added, "count \(count)")
            #expect(Array(built) == values, "count \(count)")
        }
    }
}
