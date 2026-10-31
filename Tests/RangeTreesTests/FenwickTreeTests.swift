// Each test is self-contained: it builds its own trees and states its own expectations, so it can
// be copied into another file and still run. Nothing here is shared but the imports.

import Foundation
import GrafluentCollectionsTestSupport
import RangeTrees
import Testing
import Trees

@Suite("FenwickTree: hand-worked cases")
struct FenwickTreeTests {
    @Test("The prefix sums of 1 through 8 are the triangular numbers")
    func prefixSums() {
        let tree: FenwickTree = [1, 2, 3, 4, 5, 6, 7, 8]
        let expected: [Int] = [1, 3, 6, 10, 15, 21, 28, 36]
        let sums = (0 ..< 8).map { tree.prefixSum(through: $0) }
        #expect(sums == expected)
    }

    @Test("A range sum is the difference of two prefix sums")
    func rangeSums() {
        let tree: FenwickTree = [1, 2, 3, 4, 5, 6, 7, 8]
        let middle: Int = 12
        let whole: Int = 36
        let last: Int = 8
        let first: Int = 1
        let empty: Int = 0
        #expect(tree.sum(in: 2 ..< 5) == middle)
        #expect(tree.sum(in: 0 ..< 8) == whole)
        #expect(tree.sum(in: 7 ..< 8) == last)
        #expect(tree.sum(in: 0 ..< 1) == first)
        #expect(tree.sum(in: 3 ..< 3) == empty)
        #expect(tree.sum(in: 8 ..< 8) == empty)
    }

    @Test("Every range of 1 through 8 sums to its arithmetic series", .tags(.exhaustive))
    func everyRange() {
        let values = Array(1 ... 8)
        let tree = FenwickTree(values)
        for lower in 0 ... 8 {
            for upper in lower ... 8 {
                let expected = values[lower ..< upper].reduce(0, +)
                #expect(tree.sum(in: lower ..< upper) == expected, "range \(lower) ..< \(upper)")
            }
        }
    }

    @Test("add(_:at:) changes the prefix sums at and after its index only")
    func add() {
        var tree: FenwickTree = [1, 2, 3, 4, 5, 6, 7, 8]
        tree.add(10, at: 2)
        let expected: [Int] = [1, 3, 16, 20, 25, 31, 38, 46]
        let sums = (0 ..< 8).map { tree.prefixSum(through: $0) }
        #expect(sums == expected)
        let values: [Int] = [1, 2, 13, 4, 5, 6, 7, 8]
        #expect(Array(tree) == values)
    }

    @Test("add(_:at:) takes negative amounts")
    func addNegative() {
        var tree: FenwickTree = [5, 5, 5]
        tree.add(-5, at: 1)
        let values: [Int] = [5, 0, 5]
        let total: Int = 10
        #expect(Array(tree) == values)
        #expect(tree.prefixSum(through: 2) == total)
    }

    @Test("The subscript reads back each value")
    func subscriptReadsValues() {
        let values: [Int] = [4, -1, 7, 0, 3, 3, 9, 2, 6]
        let tree = FenwickTree(values)
        #expect(tree.count == 9)
        for index in values.indices {
            #expect(tree[index] == values[index])
        }
        #expect(Array(tree) == values)
    }

    @Test("lowerBound(ofPrefixSum:) finds the first index whose prefix sum reaches the value")
    func lowerBound() {
        let tree: FenwickTree = [1, 2, 3, 4, 5, 6, 7, 8]
        let exact: Int = 3
        let between: Int = 4
        let first: Int = 0
        let last: Int = 7
        #expect(tree.lowerBound(ofPrefixSum: 10) == exact)
        #expect(tree.lowerBound(ofPrefixSum: 11) == between)
        #expect(tree.lowerBound(ofPrefixSum: 1) == first)
        #expect(tree.lowerBound(ofPrefixSum: 36) == last)
    }

    @Test("lowerBound(ofPrefixSum:) is 0 for a value at most zero and endIndex above the total")
    func lowerBoundEdges() {
        let tree: FenwickTree = [1, 2, 3, 4, 5, 6, 7, 8]
        let start: Int = 0
        #expect(tree.lowerBound(ofPrefixSum: 0) == start)
        #expect(tree.lowerBound(ofPrefixSum: -5) == start)
        #expect(tree.lowerBound(ofPrefixSum: 37) == tree.endIndex)
    }

    @Test("lowerBound(ofPrefixSum:) skips leading zeros, and a zero total reaches only zero")
    func lowerBoundZeros() {
        let zeros: FenwickTree = [0, 0, 0, 0, 0]
        let start: Int = 0
        #expect(zeros.lowerBound(ofPrefixSum: 0) == start)
        #expect(zeros.lowerBound(ofPrefixSum: 1) == zeros.endIndex)
        let leading: FenwickTree = [0, 0, 0, 4, 0, 2]
        let four: Int = 3
        let five: Int = 5
        #expect(leading.lowerBound(ofPrefixSum: 1) == four)
        #expect(leading.lowerBound(ofPrefixSum: 4) == four)
        #expect(leading.lowerBound(ofPrefixSum: 5) == five)
        #expect(leading.lowerBound(ofPrefixSum: 7) == leading.endIndex)
    }

    @Test("An empty tree has no values, sums its empty range to zero and has lowerBound 0")
    func empty() {
        let tree = FenwickTree<Int>()
        let zero: Int = 0
        #expect(tree.isEmpty)
        #expect(tree.count == 0)
        #expect(Array(tree) == [])
        #expect(tree.sum(in: 0 ..< 0) == zero)
        #expect(tree.lowerBound(ofPrefixSum: 0) == zero)
        #expect(tree.lowerBound(ofPrefixSum: 1) == zero)
        #expect(tree == [])
    }

    @Test("A one-element tree sums and finds its one value")
    func oneElement() {
        var tree: FenwickTree = [7]
        let seven: Int = 7
        let start: Int = 0
        #expect(tree.prefixSum(through: 0) == seven)
        #expect(tree.sum(in: 0 ..< 1) == seven)
        #expect(tree[0] == seven)
        #expect(tree.lowerBound(ofPrefixSum: 7) == start)
        #expect(tree.lowerBound(ofPrefixSum: 8) == tree.endIndex)
        tree.add(3, at: 0)
        let ten: Int = 10
        #expect(tree[0] == ten)
    }

    @Test("Floating-point elements sum like integers on exactly representable values")
    func floatingPoint() {
        let tree: FenwickTree<Double> = [0.5, 0.25, 1.5, 2]
        let prefix: Double = 2.25
        let range: Double = 3.75
        let reachesTwo: Int = 2
        #expect(tree.prefixSum(through: 2) == prefix)
        #expect(tree.sum(in: 1 ..< 4) == range)
        #expect(tree.lowerBound(ofPrefixSum: 2) == reachesTwo)
    }

    @Test("The sums of values near Int.max stay in range without overflowing")
    func largeValues() {
        let tree: FenwickTree = [Int.max - 2, 1, 1, -Int.max]
        let total: Int = 0
        #expect(tree.prefixSum(through: 2) == Int.max)
        #expect(tree.sum(in: 1 ..< 3) == 2)
        #expect(tree.prefixSum(through: 3) == total)
        #expect(Array(tree) == [Int.max - 2, 1, 1, -Int.max])
    }

    @Test("Adding to a copy leaves the original alone", .tags(.copyOnWrite))
    func copyOnWrite() {
        let original: FenwickTree = [1, 2, 3]
        var copy = original
        copy.add(5, at: 0)
        let originalValues: [Int] = [1, 2, 3]
        let copyValues: [Int] = [6, 2, 3]
        #expect(Array(original) == originalValues)
        #expect(Array(copy) == copyValues)
        #expect(original != copy)
    }

    @Test("Trees are equal when their values are, however they were built", .tags(.conformance))
    func equality() {
        var added: FenwickTree = [0, 0, 0, 0]
        added.add(1, at: 0)
        added.add(2, at: 1)
        added.add(3, at: 2)
        added.add(4, at: 3)
        let built: FenwickTree = [1, 2, 3, 4]
        #expect(added == built)
        #expect(added.hashValue == built.hashValue)
        #expect(built != [1, 2, 3])
        #expect(built != [1, 2, 3, 5])
    }

    @Test("Codable round-trips the values as a plain array", .tags(.conformance))
    func codable() throws {
        let tree: FenwickTree = [3, 1, 4, 1, 5, 9, 2, 6]
        let data = try JSONEncoder().encode(tree)
        let asArray = try JSONDecoder().decode([Int].self, from: data)
        let values: [Int] = [3, 1, 4, 1, 5, 9, 2, 6]
        #expect(asArray == values)
        let decoded = try JSONDecoder().decode(FenwickTree<Int>.self, from: data)
        #expect(decoded == tree)
        let total: Int = 31
        #expect(decoded.prefixSum(through: 7) == total)
    }

    @Test("The description is the values written as an array", .tags(.conformance))
    func description() {
        let tree: FenwickTree = [1, 2, 3]
        let expected = "[1, 2, 3]"
        #expect(tree.description == expected)
        #expect(FenwickTree<Int>().description == "[]")
    }

    @Test("The checked spellings throw IndexOutOfRange outside the indices")
    func checkedThrows() {
        var tree: FenwickTree = [1, 2, 3]
        #expect(throws: IndexOutOfRange()) { try tree.prefixSum(checkedThrough: 3) }
        #expect(throws: IndexOutOfRange()) { try tree.prefixSum(checkedThrough: -1) }
        #expect(throws: IndexOutOfRange()) { try tree.sum(checkedIn: 0 ..< 4) }
        #expect(throws: IndexOutOfRange()) { try tree.sum(checkedIn: -1 ..< 2) }
        #expect(throws: IndexOutOfRange()) { try tree[checked: 3] }
        #expect(throws: IndexOutOfRange()) { try tree[checked: -1] }
        #expect(throws: IndexOutOfRange()) { try tree.add(1, checkedAt: 3) }
        #expect(throws: IndexOutOfRange()) { try tree.add(1, checkedAt: -1) }
        let values: [Int] = [1, 2, 3]
        #expect(Array(tree) == values)
        #expect(throws: IndexOutOfRange()) { try FenwickTree<Int>().prefixSum(checkedThrough: 0) }
    }

    @Test("The checked spellings agree with the plain ones inside the indices")
    func checkedAgrees() throws {
        var tree: FenwickTree = [1, 2, 3, 4]
        #expect(try tree.prefixSum(checkedThrough: 2) == tree.prefixSum(through: 2))
        #expect(try tree.sum(checkedIn: 1 ..< 4) == tree.sum(in: 1 ..< 4))
        #expect(try tree.sum(checkedIn: 4 ..< 4) == tree.sum(in: 4 ..< 4))
        #expect(try tree[checked: 3] == tree[3])
        try tree.add(6, checkedAt: 1)
        let values: [Int] = [1, 8, 3, 4]
        #expect(Array(tree) == values)
    }

    @Test("The update tree of eight cells is rooted at the end vertex, 8")
    func arborescenceOfEight() {
        let tree: FenwickTree = [1, 2, 3, 4, 5, 6, 7, 8]
        let arborescence = Arborescence(tree)
        let root: Int = 8
        let expected: [Int?] = [1, 3, 3, 7, 5, 7, 7, 8, nil]
        #expect(arborescence.vertexCount == 9)
        #expect(arborescence.root == root)
        #expect((0 ... 8).map { arborescence.parent(of: $0) } == expected)
    }

    @Test("The update tree of seven cells hangs every cell that leaves the array from the end vertex")
    func arborescenceOfSeven() {
        let tree: FenwickTree = [1, 2, 3, 4, 5, 6, 7]
        let arborescence = Arborescence(tree)
        let root: Int = 7
        let expected: [Int?] = [1, 3, 3, 7, 5, 7, 7, nil]
        let rootChildren: [Int] = [3, 5, 6]
        #expect(arborescence.root == root)
        #expect((0 ... 7).map { arborescence.parent(of: $0) } == expected)
        #expect(arborescence.children(of: 7).sorted() == rootChildren)
    }

    @Test("The update tree of an empty Fenwick tree is the end vertex alone")
    func arborescenceOfEmpty() {
        let arborescence = Arborescence(FenwickTree<Int>())
        let root: Int = 0
        #expect(arborescence.vertexCount == 1)
        #expect(arborescence.root == root)
    }

    @Test("An add at a cell touches exactly the cells on its path to the root of the update tree")
    func arborescencePathsAreUpdates() {
        let count = 13
        let arborescence = Arborescence(FenwickTree([Int](repeating: 0, count: count)))
        for cell in 0 ..< count {
            var touched = FenwickTree([Int](repeating: 0, count: count))
            touched.add(1, at: cell)
            var path: [Int] = []
            var vertex: Int? = cell
            while let current = vertex, current < count {
                path.append(current)
                vertex = arborescence.parent(of: current)
            }
            // Cell k covers the values k & (k + 1) through k, so it holds the added 1 exactly
            // when it is on the path.
            let covering = (0 ..< count).filter { k in (k & (k + 1)) <= cell && cell <= k }
            #expect(path == covering, "cell \(cell)")
            #expect(touched.sum(in: 0 ..< count) == 1)
        }
    }

    @Test("The plain spellings trap outside the indices", .tags(.precondition))
    func plainTraps() async {
        await #expect(processExitsWith: .failure) {
            let tree: FenwickTree = [1, 2, 3]
            _ = tree.prefixSum(through: 3)
        }
        await #expect(processExitsWith: .failure) {
            let tree: FenwickTree = [1, 2, 3]
            _ = tree.prefixSum(through: -1)
        }
        await #expect(processExitsWith: .failure) {
            let tree: FenwickTree = [1, 2, 3]
            _ = tree.sum(in: 1 ..< 4)
        }
        await #expect(processExitsWith: .failure) {
            let tree: FenwickTree = [1, 2, 3]
            _ = tree.sum(in: -1 ..< 1)
        }
        await #expect(processExitsWith: .failure) {
            let tree: FenwickTree = [1, 2, 3]
            _ = tree[3]
        }
        await #expect(processExitsWith: .failure) {
            var tree: FenwickTree = [1, 2, 3]
            tree.add(1, at: 3)
        }
        await #expect(processExitsWith: .failure) {
            var tree: FenwickTree = [1, 2, 3]
            tree.add(1, at: -1)
        }
        await #expect(processExitsWith: .failure) {
            _ = FenwickTree<Int>().prefixSum(through: 0)
        }
    }

    @Test("Building or adding past Int.max traps on overflow, like the sum itself", .tags(.precondition))
    func overflowTraps() async {
        await #expect(processExitsWith: .failure) {
            _ = FenwickTree([Int.max, 1])
        }
        await #expect(processExitsWith: .failure) {
            var tree: FenwickTree = [Int.max, 0]
            tree.add(1, at: 0)
        }
    }
}
