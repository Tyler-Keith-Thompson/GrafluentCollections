// FenwickTree, SegmentTree and LazySegmentTree against an array, and IntervalTree against a list
// of intervals. After every update every range query must agree with a loop over the array, and
// every search with a filter over the list.

import FuzzSupport
import RangeTrees

enum AddToSum: MonoidAction {
    typealias Values = Sum<Int>
    static var identity: Int { 0 }
    static func compose(_ outer: Int, _ inner: Int) -> Int { outer &+ inner }
    static func apply(_ update: Int, to sum: Int, count: Int) -> Int { sum &+ update &* count }
}

@main
enum FuzzRangeTrees {
    static func main() { runFuzzer(fuzz) }

    static func fuzz(_ input: inout FuzzInput) {
        if input.int(below: 2) == 0 { arrays(&input) } else { intervals(&input) }
    }

    static func arrays(_ input: inout FuzzInput) {
        var values = (0 ..< input.int(below: 40)).map { _ in input.int(in: -8 ... 8) }
        var fenwick = FenwickTree(values)
        var sums = SegmentTree<Sum<Int>>(values)
        var minima = SegmentTree<Minimum<Int>>(values)
        var lazy = LazySegmentTree<AddToSum>(values)
        while !input.isEmpty {
            let n = values.count
            let a = input.int(below: n + 1), b = input.int(below: n + 1)
            let range = min(a, b) ..< max(a, b)
            let value = input.int(in: -8 ... 8)
            switch input.int(below: 3) {
            case 0 where n > 0:
                let index = a % n
                fenwick.add(value - values[index], at: index)
                sums.update(at: index, to: value)
                minima.update(at: index, to: value)
                lazy.update(at: index, to: value)
                values[index] = value
            case 1:
                for index in range {
                    fenwick.add(value, at: index)
                    sums.update(at: index, to: values[index] + value)
                    minima.update(at: index, to: values[index] + value)
                    values[index] += value
                }
                lazy.apply(value, in: range)
            default:
                break
            }
            let total = values[range].reduce(0, +)
            check(fenwick.sum(in: range) == total, "FenwickTree.sum(in: \(range))")
            check(sums.combined(in: range) == total, "SegmentTree<Sum>.combined(in: \(range))")
            check(minima.combined(in: range) == (values[range].min() ?? Int.max), "SegmentTree<Minimum>.combined(in: \(range))")
            check(lazy.combined(in: range) == total, "LazySegmentTree.combined(in: \(range))")
            if range.lowerBound < n {
                let limit = abs(value) * 3
                // The guarantee for any predicate that holds for the identity: it holds for the
                // run up to the end returned, and fails once one more element is added.
                let end = sums.maxRight(from: range.lowerBound) { $0 <= limit }
                check(end >= range.lowerBound && end <= n, "maxRight(from: \(range.lowerBound)) out of range")
                check(values[range.lowerBound ..< end].reduce(0, +) <= limit, "maxRight(from: \(range.lowerBound)): the run fails")
                check(end == n || values[range.lowerBound ... end].reduce(0, +) > limit, "maxRight(from: \(range.lowerBound)): the run could go on")
            }
        }
        check(Array(fenwick) == values && Array(sums) == values && Array(minima) == values && Array(lazy) == values, "values")
    }

    static func intervals(_ input: inout FuzzInput) {
        var tree = IntervalTree<Int, Int>()
        var model: [(range: Range<Int>, value: Int)] = []
        var serial = 0
        while !input.isEmpty {
            let a = input.int(below: 24), b = input.int(below: 24)
            let range = min(a, b) ..< max(a, b) + 1
            serial += 1
            switch input.int(below: 4) {
            case 0, 1:
                tree.insert(range, value: serial)
                model.append((range, serial))
            case 2:
                let removed = tree.remove(range)
                if let index = model.firstIndex(where: { $0.range == range }) {
                    check(removed != nil, "remove(\(range)) found nothing")
                    if let removed { model.remove(at: model.firstIndex { $0.range == range && $0.value == removed }!) }
                    _ = index
                } else {
                    check(removed == nil, "remove(\(range)) removed an absent range")
                }
            default:
                break
            }
            let point = a
            let overlapping = model.filter { $0.range.overlaps(range) }.map(\.value).sorted()
            check(tree.overlapping(range).map(\.value).sorted() == overlapping, "overlapping(\(range))")
            let containing = model.filter { $0.range.contains(point) }.map(\.value).sorted()
            check(tree.containing(point).map(\.value).sorted() == containing, "containing(\(point))")
            let contained = model.filter { range.lowerBound <= $0.range.lowerBound && $0.range.upperBound <= range.upperBound }.map(\.value).sorted()
            check(tree.contained(in: range).map(\.value).sorted() == contained, "contained(in: \(range))")
            check(tree.count == model.count, "count")
        }
    }
}
