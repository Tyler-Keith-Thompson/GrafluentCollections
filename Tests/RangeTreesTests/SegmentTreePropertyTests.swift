// Property tests against a naive reference: a plain array, combined with `reduce` after every
// update. Each test is self-contained; see SegmentTreeTests.swift.

import GrafluentCollectionsTestSupport
import PropertyBased
import RangeTrees
import Testing

@Suite("SegmentTree: properties")
struct SegmentTreePropertyTests {
    @Test("After any updates, every range's sum, minimum and concatenation matches the array's", .tags(.randomized))
    func matchesArray() async {
        enum Concatenation: Monoid {
            static var identity: String { "" }
            static func combine(_ lhs: String, _ rhs: String) -> String { lhs + rhs }
        }
        let values = Gen.int(in: -1_000 ... 1_000).array(of: 0 ... 40)
        let updates = zip(Gen.int(in: 0 ... 1_000), Gen.int(in: -1_000 ... 1_000)).array(of: 0 ... 30)
        await propertyCheck(count: 200, input: values, updates) { values, updates in
            var reference = values
            var sums = SegmentTree<Sum<Int>>(values)
            var minima = SegmentTree<Minimum<Int>>(values)
            var words = SegmentTree<Concatenation>(values.map { "\($0)," })
            for (position, value) in updates where !reference.isEmpty {
                let index = position % reference.count
                reference[index] = value
                sums.update(at: index, to: value)
                minima.update(at: index, to: value)
                words.update(at: index, to: "\(value),")
            }
            #expect(Array(sums) == reference)
            for lower in 0 ... reference.count {
                for upper in lower ... reference.count {
                    let slice = reference[lower ..< upper]
                    #expect(sums.combined(in: lower ..< upper) == slice.reduce(0, +))
                    #expect(minima.combined(in: lower ..< upper) == slice.min() ?? Int.max)
                    #expect(words.combined(in: lower ..< upper) == slice.map { "\($0)," }.joined())
                }
            }
        }
    }

    @Test("maxRight and minLeft agree with a scan of running sums over non-negative values", .tags(.randomized))
    func binarySearchesMatchScan() async {
        let values = Gen.int(in: 0 ... 20).array(of: 0 ... 40)
        let bounds = Gen.int(in: 0 ... 300).array(of: 1 ... 10)
        await propertyCheck(count: 200, input: values, bounds) { values, bounds in
            let tree = SegmentTree<Sum<Int>>(values)
            for bound in bounds {
                for start in 0 ... values.count {
                    var end = start, running = 0
                    while end < values.count && running + values[end] <= bound {
                        running += values[end]
                        end += 1
                    }
                    #expect(tree.maxRight(from: start) { $0 <= bound } == end)
                }
                for end in 0 ... values.count {
                    var start = end, running = 0
                    while start > 0 && running + values[start - 1] <= bound {
                        running += values[start - 1]
                        start -= 1
                    }
                    #expect(tree.minLeft(upTo: end) { $0 <= bound } == start)
                }
            }
        }
    }

    @Test("A lazy tree under mixed affine range updates and point updates matches the array", .tags(.randomized))
    func lazyMatchesArray() async {
        struct Affine { var a: Int, b: Int }
        enum AffineOnSum: MonoidAction {
            typealias Values = Sum<Int>
            static var identity: Affine { Affine(a: 1, b: 0) }
            static func compose(_ outer: Affine, _ inner: Affine) -> Affine {
                Affine(a: outer.a &* inner.a, b: outer.a &* inner.b &+ outer.b)
            }
            static func apply(_ update: Affine, to sum: Int, count: Int) -> Int {
                update.a &* sum &+ update.b &* count
            }
        }
        let values = Gen.int(in: -100 ... 100).array(of: 0 ... 30)
        let operations = Gen.int(in: 0 ... 10_000_000).array(of: 0 ... 30)
        await propertyCheck(count: 200, input: values, operations) { values, operations in
            var reference = values
            var tree = LazySegmentTree<AffineOnSum>(values)
            for operation in operations where !reference.isEmpty {
                let n = reference.count
                let x = operation % (n + 1), y = operation / 7 % (n + 1)
                let range = min(x, y) ..< max(x, y)
                let a = operation / 49 % 3 - 1, b = operation / 147 % 11 - 5
                if operation / 1_617 % 4 == 0 {
                    let index = operation % n
                    reference[index] = b
                    tree.update(at: index, to: b)
                } else {
                    for k in range {
                        reference[k] = a &* reference[k] &+ b
                    }
                    tree.apply(Affine(a: a, b: b), in: range)
                }
            }
            #expect(Array(tree) == reference)
            for lower in 0 ... reference.count {
                for upper in lower ... reference.count {
                    #expect(tree.combined(in: lower ..< upper) == reference[lower ..< upper].reduce(0, &+))
                }
            }
        }
    }
}
