// Tests for SegmentTree, LazySegmentTree and the monoids. Each test defines the monoids and
// actions it needs and checks against a hand-worked answer, so it can be copied into another file
// and still run. Nothing here is shared but the imports.

import GrafluentCollectionsTestSupport
import RangeTrees
import Testing
import Trees

@Suite("SegmentTree: hand-worked cases")
struct SegmentTreeTests {
    @Test("Sum, product, minimum and maximum over [5, 3, 8, 6, 1, 9]")
    func standardMonoids() {
        let values = [5, 3, 8, 6, 1, 9]
        let sums = SegmentTree<Sum<Int>>(values)
        let products = SegmentTree<Product<Int>>(values)
        let minima = SegmentTree<Minimum<Int>>(values)
        let maxima = SegmentTree<Maximum<Int>>(values)
        let sum = 18, product = 120, minimum = 1, maximum = 8
        #expect(sums.combined(in: 1 ..< 5) == sum)
        #expect(products.combined(in: 0 ..< 3) == product)
        #expect(minima.combined(in: 1 ..< 5) == minimum)
        #expect(maxima.combined(in: 0 ..< 4) == maximum)
        #expect(Array(sums) == values)
    }

    @Test("gcd is a monoid with identity 0")
    func gcd() {
        enum GreatestCommonDivisor: Monoid {
            static var identity: Int { 0 }
            static func combine(_ lhs: Int, _ rhs: Int) -> Int {
                var (a, b) = (lhs, rhs)
                while b != 0 { (a, b) = (b, a % b) }
                return a
            }
        }
        let tree = SegmentTree<GreatestCommonDivisor>([12, 18, 24, 7, 14, 21])
        let six = 6, seven = 7, one = 1
        #expect(tree.combined(in: 0 ..< 3) == six)
        #expect(tree.combined(in: 3 ..< 6) == seven)
        #expect(tree.combined(in: 2 ..< 4) == one)
    }

    @Test("Concatenation keeps index order, so a non-commutative monoid reads its range left to right")
    func concatenationKeepsOrder() {
        enum Concatenation: Monoid {
            static var identity: String { "" }
            static func combine(_ lhs: String, _ rhs: String) -> String { lhs + rhs }
        }
        var tree = SegmentTree<Concatenation>(["a", "b", "c", "d", "e", "f", "g"])
        let middle = "bcdef", all = "abcdefg"
        #expect(tree.combined(in: 1 ..< 6) == middle)
        #expect(tree.combined(in: tree.indices) == all)
        tree.update(at: 3, to: "X")
        let updated = "cXe"
        #expect(tree.combined(in: 2 ..< 5) == updated)
        for lower in 0 ... 7 {
            for upper in lower ... 7 {
                #expect(tree.combined(in: lower ..< upper) == tree[lower ..< upper].joined())
            }
        }
    }

    @Test("2×2 matrix products come out in index order")
    func matrixProduct() {
        struct Matrix: Equatable {
            var a, b, c, d: Int
        }
        enum MatrixProduct: Monoid {
            static var identity: Matrix { Matrix(a: 1, b: 0, c: 0, d: 1) }
            static func combine(_ x: Matrix, _ y: Matrix) -> Matrix {
                Matrix(a: x.a * y.a + x.b * y.c, b: x.a * y.b + x.b * y.d, c: x.c * y.a + x.d * y.c, d: x.c * y.b + x.d * y.d)
            }
        }
        let shear = Matrix(a: 1, b: 1, c: 0, d: 1)
        let swap = Matrix(a: 0, b: 1, c: 1, d: 0)
        let tree = SegmentTree<MatrixProduct>([shear, swap, shear])
        // shear · swap = [[1, 1], [1, 0]], and swap · shear = [[0, 1], [1, 1]].
        let inOrder = Matrix(a: 1, b: 1, c: 1, d: 0)
        let reversed = Matrix(a: 0, b: 1, c: 1, d: 1)
        #expect(tree.combined(in: 0 ..< 2) == inOrder)
        #expect(tree.combined(in: 1 ..< 3) == reversed)
        let all = Matrix(a: 1, b: 2, c: 1, d: 1)
        #expect(tree.combined(in: 0 ..< 3) == all)
    }

    @Test("Counts that are not powers of two: 0, 1, 5 and 17 values")
    func awkwardCounts() {
        for count in [0, 1, 5, 17] {
            let values = Array(1 ... max(count, 1)).prefix(count)
            let tree = SegmentTree<Sum<Int>>(values)
            #expect(tree.count == count)
            for lower in 0 ... count {
                for upper in lower ... count {
                    #expect(tree.combined(in: lower ..< upper) == values[lower ..< upper].reduce(0, +))
                }
            }
        }
    }

    @Test("An empty range combines to the identity, even at endIndex")
    func emptyRange() {
        let tree = SegmentTree<Minimum<Int>>([4, 2])
        let identity = Int.max
        #expect(tree.combined(in: 1 ..< 1) == identity)
        #expect(tree.combined(in: 2 ..< 2) == identity)
        let empty = SegmentTree<Sum<Int>>()
        let zero = 0
        #expect(empty.combined(in: 0 ..< 0) == zero)
        #expect(empty.isEmpty)
    }

    @Test("maxRight and minLeft find where a running sum crosses a bound")
    func binarySearches() {
        let tree: SegmentTree<Sum<Int>> = [3, 1, 4, 1, 5, 9, 2, 6]
        // Sums from 2: 4, 5, 10, 19, …
        let fromTwo = 4
        #expect(tree.maxRight(from: 2) { $0 <= 9 } == fromTwo)
        let everything = 8, nothing = 0
        #expect(tree.maxRight(from: 0) { $0 <= 100 } == everything)
        #expect(tree.maxRight(from: 0) { $0 < 3 } == nothing)
        #expect(tree.maxRight(from: 8) { $0 < 3 } == everything)
        // Sums ending at 6 (exclusive), leftward: 9, 14, 15, 19, …
        let toSix = 3
        #expect(tree.minLeft(upTo: 6) { $0 <= 15 } == toSix)
        #expect(tree.minLeft(upTo: 8) { $0 <= 100 } == nothing)
        let six = 6
        #expect(tree.minLeft(upTo: 6) { $0 < 9 } == six)
        #expect(tree.minLeft(upTo: 0) { $0 < 1 } == nothing)
    }

    @Test("update replaces a value, and a copy keeps the old one")
    func updateAndValueSemantics() {
        var tree: SegmentTree<Sum<Int>> = [1, 2, 3]
        let copy = tree
        tree.update(at: 1, to: 20)
        let updated = 24, original = 6
        #expect(tree.combined(in: 0 ..< 3) == updated)
        #expect(copy.combined(in: 0 ..< 3) == original)
        #expect(tree != copy)
        #expect(tree == SegmentTree<Sum<Int>>([1, 20, 3]))
        let description = "[1, 20, 3]"
        #expect(tree.description == description)
    }

    @Test("The shape is a perfect binary tree over the values padded to a power of two")
    func binaryTreeShape() throws {
        let tree = SegmentTree<Sum<Int>>([1, 2, 3, 4, 5])
        let shape = try #require(BinaryTree(tree))
        let vertices = 15, height = 3, root = 0
        #expect(shape.vertexCount == vertices)
        #expect(shape.height == height)
        #expect(shape.root == root)
        let left: Int? = 5, right: Int? = 6
        #expect(shape.left(of: 2) == left)
        #expect(shape.right(of: 2) == right)
        #expect(BinaryTree(SegmentTree<Sum<Int>>()) == nil)
        let one = try #require(BinaryTree(SegmentTree<Sum<Int>>([7])))
        let single = 1
        #expect(one.vertexCount == single)
    }

    @Test("The checked spellings throw IndexOutOfRange and change nothing")
    func checkedSpellings() throws {
        var tree: SegmentTree<Sum<Int>> = [1, 2, 3]
        let six = 6, two = 2
        #expect(try tree.combined(checkedIn: 0 ..< 3) == six)
        #expect(try tree[checked: 1] == two)
        #expect(throws: IndexOutOfRange()) { try tree.combined(checkedIn: 0 ..< 4) }
        #expect(throws: IndexOutOfRange()) { try tree[checked: 3] }
        #expect(throws: IndexOutOfRange()) { try tree.update(checkedAt: -1, to: 0) }
        #expect(throws: IndexOutOfRange()) { try tree.maxRight(checkedFrom: 4) { _ in true } }
        #expect(throws: IndexOutOfRange()) { try tree.minLeft(checkedUpTo: -1) { _ in true } }
        try tree.update(checkedAt: 2, to: 10)
        let thirteen = 13
        #expect(tree.combined(in: 0 ..< 3) == thirteen)
        let one = 1, three = 3
        #expect(try tree.maxRight(checkedFrom: 0) { $0 < 3 } == one)
        #expect(try tree.minLeft(checkedUpTo: 3) { $0 < 3 } == three)
    }

}

@Suite("LazySegmentTree: hand-worked cases")
struct LazySegmentTreeTests {
    @Test("Range add then range sum")
    func rangeAddRangeSum() {
        enum AddToSum: MonoidAction {
            typealias Values = Sum<Int>
            static var identity: Int { 0 }
            static func compose(_ outer: Int, _ inner: Int) -> Int { outer + inner }
            static func apply(_ update: Int, to sum: Int, count: Int) -> Int { sum + update * count }
        }
        var tree = LazySegmentTree<AddToSum>([1, 2, 3, 4, 5])
        tree.apply(10, in: 1 ..< 4)
        let total = 45, middle = 13
        #expect(tree.combined(in: 0 ..< 5) == total)
        #expect(tree[2] == middle)
        tree.apply(-1, in: 0 ..< 2)
        let afterSecond = [0, 11, 13, 14, 5], pair = 24
        #expect(Array(tree) == afterSecond)
        #expect(tree.combined(in: 1 ..< 3) == pair)
        tree.update(at: 1, to: 100)
        let afterUpdate = [0, 100, 13, 14, 5], updatedTotal = 132
        #expect(Array(tree) == afterUpdate)
        #expect(tree.combined(in: 0 ..< 5) == updatedTotal)
    }

    @Test("Range assign then range min")
    func rangeAssignRangeMin() {
        enum AssignToMinimum: MonoidAction {
            typealias Values = Minimum<Int>
            static var identity: Int? { nil }
            static func compose(_ outer: Int?, _ inner: Int?) -> Int? { outer ?? inner }
            static func apply(_ update: Int?, to minimum: Int, count: Int) -> Int { update ?? minimum }
        }
        var tree = LazySegmentTree<AssignToMinimum>([5, 3, 8, 6, 1, 9, 4])
        tree.apply(7, in: 2 ..< 6)
        let assigned = [5, 3, 7, 7, 7, 7, 4]
        #expect(Array(tree) == assigned)
        let three = 3, four = 4
        #expect(tree.combined(in: 0 ..< 7) == three)
        #expect(tree.combined(in: 2 ..< 7) == four)
        tree.apply(2, in: 3 ..< 4)
        tree.apply(9, in: 0 ..< 3)
        let reassigned = [9, 9, 9, 2, 7, 7, 4], nine = 9
        #expect(Array(tree) == reassigned)
        #expect(tree.combined(in: 0 ..< 3) == nine)
    }

    @Test("A lazy tree over a non-commutative monoid reads every range left to right after overlapping updates")
    func lazyConcatenationKeepsOrder() {
        enum Concatenation: Monoid {
            static var identity: String { "" }
            static func combine(_ lhs: String, _ rhs: String) -> String { lhs + rhs }
        }
        // An update swaps the case of every letter in its range; two swaps cancel.
        enum SwapCase: MonoidAction {
            typealias Values = Concatenation
            static var identity: Bool { false }
            static func compose(_ outer: Bool, _ inner: Bool) -> Bool { outer != inner }
            static func apply(_ update: Bool, to text: String, count: Int) -> String {
                guard update else { return text }
                return String(text.map { $0.isUppercase ? Character($0.lowercased()) : Character($0.uppercased()) })
            }
        }
        let letters: [String] = "abcdefghijklm".map { String($0) }
        var tree = LazySegmentTree<SwapCase>(letters)
        tree.apply(true, in: 2 ..< 9)
        tree.apply(true, in: 5 ..< 13)
        tree.apply(true, in: 0 ..< 4)
        let expected: [String] = "ABcdEfghiJKLM".map { String($0) }
        #expect(Array(tree) == expected)
        let all = "ABcdEfghiJKLM"
        #expect(tree.combined(in: tree.indices) == all)
        for lower in 0 ... expected.count {
            for upper in lower ... expected.count {
                #expect(tree.combined(in: lower ..< upper) == expected[lower ..< upper].joined())
            }
        }
    }

    @Test("Affine updates compose in the order they were made")
    func affineOrder() {
        // x ↦ a·x + b, acting on sums: a·sum + b·count.
        struct Affine { var a: Int, b: Int }
        enum AffineOnSum: MonoidAction {
            typealias Values = Sum<Int>
            static var identity: Affine { Affine(a: 1, b: 0) }
            static func compose(_ outer: Affine, _ inner: Affine) -> Affine {
                Affine(a: outer.a * inner.a, b: outer.a * inner.b + outer.b)
            }
            static func apply(_ update: Affine, to sum: Int, count: Int) -> Int { update.a * sum + update.b * count }
        }
        var tree = LazySegmentTree<AffineOnSum>([1, 2, 3, 4])
        tree.apply(Affine(a: 2, b: 0), in: 0 ..< 4)   // [2, 4, 6, 8]
        tree.apply(Affine(a: 1, b: 3), in: 1 ..< 3)   // [2, 7, 9, 8]
        tree.apply(Affine(a: 0, b: 5), in: 2 ..< 4)   // [2, 7, 5, 5]
        tree.apply(Affine(a: 3, b: 0), in: 0 ..< 3)   // [6, 21, 15, 5]
        let expected = [6, 21, 15, 5], tail = 41
        #expect(Array(tree) == expected)
        #expect(tree.combined(in: 1 ..< 4) == tail)
    }

    @Test("The checked spellings throw IndexOutOfRange and change nothing")
    func checkedSpellings() throws {
        enum AddToSum: MonoidAction {
            typealias Values = Sum<Int>
            static var identity: Int { 0 }
            static func compose(_ outer: Int, _ inner: Int) -> Int { outer + inner }
            static func apply(_ update: Int, to sum: Int, count: Int) -> Int { sum + update * count }
        }
        var tree: LazySegmentTree<AddToSum> = [1, 2, 3]
        #expect(throws: IndexOutOfRange()) { try tree.apply(1, checkedIn: 2 ..< 4) }
        #expect(throws: IndexOutOfRange()) { try tree.combined(checkedIn: -1 ..< 1) }
        #expect(throws: IndexOutOfRange()) { try tree.update(checkedAt: 3, to: 0) }
        #expect(throws: IndexOutOfRange()) { try tree[checked: 3] }
        let unchanged = [1, 2, 3]
        #expect(Array(tree) == unchanged)
        try tree.apply(1, checkedIn: 0 ..< 3)
        try tree.update(checkedAt: 0, to: 0)
        let seven = 7, four = 4
        #expect(try tree.combined(checkedIn: 0 ..< 3) == seven)
        #expect(try tree[checked: 2] == four)
        let shape = try #require(BinaryTree(tree))
        let vertices = 7
        #expect(shape.vertexCount == vertices)
    }

}
