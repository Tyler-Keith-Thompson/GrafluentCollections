// Each test is self-contained: it builds its own trees and states its own expectations, so it can
// be copied into another file and still run. Nothing here is shared but the imports.

import BinarySearchTrees
import Foundation
import GrafluentCollectionsTestSupport
import Testing
import Trees

@Suite("RedBlackTree: hand-worked cases")
struct RedBlackTreeTests {
    @Test("After seeded inserts and removes, color(of:) shows a black root, no red vertex with a red child, and one black count on every path")
    func colorInvariants() {
        var rng = SeededRandomNumberGenerator(seed: 40)
        var tree = RedBlackTree<Int>()
        for step in 0 ..< 600 {
            let key = Int.random(in: 0 ..< 200, using: &rng)
            if step % 3 == 2 {
                tree.remove(key)
            } else {
                tree.insert(key)
            }
            guard let shape = BinaryTree(tree) else { continue }
            #expect(tree.color(of: shape.root) == .black)
            // The number of black vertices from `key` down to each empty link below it, or nil
            // when two paths disagree or a red vertex has a red child.
            func blackHeight(_ key: Int?) -> Int? {
                guard let key else { return 0 }
                let isRed = tree.color(of: key) == .red
                for child in [shape.left(of: key), shape.right(of: key)] {
                    if isRed, let child, tree.color(of: child) == .red { return nil }
                }
                guard let left = blackHeight(shape.left(of: key)), let right = blackHeight(shape.right(of: key)), left == right else { return nil }
                return left + (isRed ? 0 : 1)
            }
            #expect(blackHeight(shape.root) != nil)
        }
    }

    @Test("color(of:) reads each vertex's colour: inserting 1, 2, 3 leaves 2 black on top of two red leaves")
    func colors() {
        var tree = RedBlackTree<Int>()
        tree.insert(1)
        let black: RedBlackTree<Int>.Color? = .black, red: RedBlackTree<Int>.Color? = .red
        #expect(tree.color(of: 1) == black)
        tree.insert(2)
        tree.insert(3)
        #expect(tree.color(of: 2) == black)
        #expect(tree.color(of: 1) == red)
        #expect(tree.color(of: 3) == red)
        // A fourth key under 3 makes 1 and 3 black and the new leaf red.
        tree.insert(4)
        #expect(tree.color(of: 1) == black)
        #expect(tree.color(of: 3) == black)
        #expect(tree.color(of: 4) == red)
        #expect(tree.color(of: 5) == nil)
        #expect(RedBlackTree<Int>().color(of: 1) == nil)
    }

    @Test("Inserting 3, 2, 1 rotates right once: 2 at the root, 1 left, 3 right")
    func leftLeftRotation() throws {
        var tree = RedBlackTree<Int>()
        tree.insert(3)
        tree.insert(2)
        tree.insert(1)
        let shape = try #require(BinaryTree(tree))
        let root: Int = 2
        #expect(shape.root == root)
        #expect(shape.left(of: 2) == 1)
        #expect(shape.right(of: 2) == 3)
        #expect(tree.height == 2)
    }

    @Test("Inserting 1, 2, 3 rotates left once: 2 at the root, 1 left, 3 right")
    func rightRightRotation() throws {
        var tree = RedBlackTree<Int>()
        tree.insert(1)
        tree.insert(2)
        tree.insert(3)
        let shape = try #require(BinaryTree(tree))
        let root: Int = 2
        #expect(shape.root == root)
        #expect(shape.left(of: 2) == 1)
        #expect(shape.right(of: 2) == 3)
    }

    @Test("Inserting 3, 1, 2 rotates left then right: 2 at the root, 1 left, 3 right")
    func leftRightRotation() throws {
        var tree = RedBlackTree<Int>()
        tree.insert(3)
        tree.insert(1)
        tree.insert(2)
        let shape = try #require(BinaryTree(tree))
        let root: Int = 2
        #expect(shape.root == root)
        #expect(shape.left(of: 2) == 1)
        #expect(shape.right(of: 2) == 3)
    }

    @Test("Inserting 1, 3, 2 rotates right then left: 2 at the root, 1 left, 3 right")
    func rightLeftRotation() throws {
        var tree = RedBlackTree<Int>()
        tree.insert(1)
        tree.insert(3)
        tree.insert(2)
        let shape = try #require(BinaryTree(tree))
        let root: Int = 2
        #expect(shape.root == root)
        #expect(shape.left(of: 2) == 1)
        #expect(shape.right(of: 2) == 3)
    }

    @Test("A rotation deep in the tree relinks the rotated subtree to its parent")
    func deepRotation() throws {
        var tree = RedBlackTree<Int>()
        for element in [50, 25, 75, 10, 5] {
            tree.insert(element)
        }
        let shape = try #require(BinaryTree(tree))
        let root: Int = 50
        #expect(shape.root == root)
        #expect(shape.left(of: 50) == 10)
        #expect(shape.left(of: 10) == 5)
        #expect(shape.right(of: 10) == 25)
        #expect(shape.right(of: 50) == 75)
        let expected: [Int] = [5, 10, 25, 50, 75]
        #expect(Array(tree) == expected)
    }

    @Test("Removing a leaf unlinks it and leaves the rest in place")
    func removeLeaf() throws {
        var tree: RedBlackTree = [1, 2, 3, 4, 5, 6, 7]
        let removed: Int? = 7
        #expect(tree.remove(7) == removed)
        let shape = try #require(BinaryTree(tree))
        let root: Int = 4
        #expect(shape.root == root)
        #expect(shape.right(of: 6) == nil)
        #expect(shape.left(of: 6) == 5)
        let expected: [Int] = [1, 2, 3, 4, 5, 6]
        #expect(Array(tree) == expected)
    }

    @Test("Removing a vertex with one child lifts the child into its place")
    func removeOneChild() throws {
        var tree: RedBlackTree = [1, 2, 3, 4, 5, 6, 7]
        tree.remove(7)
        let removed: Int? = 6
        #expect(tree.remove(6) == removed)
        let shape = try #require(BinaryTree(tree))
        #expect(shape.right(of: 4) == 5)
        #expect(shape.left(of: 5) == nil)
        #expect(shape.right(of: 5) == nil)
        let expected: [Int] = [1, 2, 3, 4, 5]
        #expect(Array(tree) == expected)
    }

    @Test("Removing a vertex with two children puts its in-order successor in its place")
    func removeTwoChildren() throws {
        var tree: RedBlackTree = [1, 2, 3, 4, 5, 6, 7]
        let removed: Int? = 2
        #expect(tree.remove(2) == removed)
        let shape = try #require(BinaryTree(tree))
        #expect(shape.left(of: 4) == 3)
        #expect(shape.left(of: 3) == 1)
        #expect(shape.right(of: 3) == nil)
        let rootRemoved: Int? = 4
        #expect(tree.remove(4) == rootRemoved)
        let afterRoot = try #require(BinaryTree(tree))
        let newRoot: Int = 5
        #expect(afterRoot.root == newRoot)
        let expected: [Int] = [1, 3, 5, 6, 7]
        #expect(Array(tree) == expected)
    }

    @Test("A removal that unbalances the root rotates it")
    func removeRotates() throws {
        var tree = RedBlackTree<Int>()
        for element in [2, 1, 3, 4] {
            tree.insert(element)
        }
        tree.remove(1)
        let shape = try #require(BinaryTree(tree))
        let root: Int = 3
        #expect(shape.root == root)
        #expect(shape.left(of: 3) == 2)
        #expect(shape.right(of: 3) == 4)
        #expect(tree.height == 2)
    }

    @Test("Removing an absent element changes nothing and returns nil")
    func removeAbsent() {
        var tree: RedBlackTree = [1, 2, 3]
        #expect(tree.remove(4) == nil)
        let expected: [Int] = [1, 2, 3]
        #expect(Array(tree) == expected)
        var empty = RedBlackTree<Int>()
        #expect(empty.remove(1) == nil)
    }

    @Test("insert(_:) reports an equal member already present, and update(with:) replaces it")
    func duplicates() {
        var tree: RedBlackTree = [1, 2, 3]
        let again = tree.insert(2)
        #expect(!again.inserted)
        #expect(again.memberAfterInsert == 2)
        #expect(tree.count == 3)
        let fresh = tree.insert(4)
        #expect(fresh.inserted)
        #expect(fresh.memberAfterInsert == 4)
        let replaced: Int? = 2
        #expect(tree.update(with: 2) == replaced)
        #expect(tree.update(with: 9) == nil)
        let expected: [Int] = [1, 2, 3, 4, 9]
        #expect(Array(tree) == expected)
    }

    @Test("Of equal elements, init keeps the first, update(with:) the new one, insert the old one")
    func equalElementsKeepTheirIdentity() {
        struct Tagged: Comparable {
            var key: Int
            var tag: String
            static func < (a: Tagged, b: Tagged) -> Bool { a.key < b.key }
            static func == (a: Tagged, b: Tagged) -> Bool { a.key == b.key }
        }
        var tree = RedBlackTree([Tagged(key: 1, tag: "first"), Tagged(key: 0, tag: "zero"), Tagged(key: 1, tag: "second")])
        let tags = tree.map(\.tag)
        let expectedTags: [String] = ["zero", "first"]
        #expect(tags == expectedTags)
        tree.insert(Tagged(key: 1, tag: "inserted"))
        #expect(tree[1].tag == "first")
        tree.update(with: Tagged(key: 1, tag: "updated"))
        #expect(tree[1].tag == "updated")
    }

    @Test("A literal or sequence with duplicates holds each element once, in ascending order")
    func initDeduplicates() {
        let tree: RedBlackTree = [5, 3, 5, 1, 3, 3, 9]
        let expected: [Int] = [1, 3, 5, 9]
        #expect(Array(tree) == expected)
        #expect(tree.count == 4)
        let sorted = RedBlackTree(1 ... 100)
        #expect(sorted.count == 100)
        #expect(Array(sorted) == Array(1 ... 100))
    }

    @Test("Indices are ranks: the subscript reads the k-th smallest element")
    func ranks() {
        let tree: RedBlackTree = [40, 10, 30, 20, 50]
        let expected: [Int] = [10, 20, 30, 40, 50]
        for (index, element) in expected.enumerated() {
            #expect(tree[index] == element)
        }
        let index: Int? = 2
        #expect(tree.firstIndex(of: 30) == index)
        #expect(tree.lastIndex(of: 30) == index)
        #expect(tree.firstIndex(of: 35) == nil)
        #expect(tree.contains(40))
        #expect(!tree.contains(45))
        let descending: [Int] = [50, 40, 30, 20, 10]
        #expect(Array(tree.reversed()) == descending)
    }

    @Test("lowerBound and upperBound bracket an element, present or not")
    func bounds() {
        let tree: RedBlackTree = [10, 20, 30, 40]
        let zero: Int = 0
        let one: Int = 1
        let two: Int = 2
        #expect(tree.lowerBound(20) == one)
        #expect(tree.upperBound(20) == two)
        #expect(tree.lowerBound(25) == two)
        #expect(tree.upperBound(25) == two)
        #expect(tree.lowerBound(5) == zero)
        #expect(tree.upperBound(5) == zero)
        #expect(tree.lowerBound(45) == tree.endIndex)
        #expect(tree.upperBound(40) == tree.endIndex)
    }

    @Test("elements(in:) is the elements in a half-open or closed range of values")
    func elementsInRange() {
        let tree: RedBlackTree = [10, 20, 30, 40, 50]
        let halfOpen: [Int] = [20, 30]
        let closed: [Int] = [20, 30, 40]
        let none: [Int] = []
        let all: [Int] = [10, 20, 30, 40, 50]
        #expect(Array(tree.elements(in: 20 ..< 40)) == halfOpen)
        #expect(Array(tree.elements(in: 20 ... 40)) == closed)
        #expect(Array(tree.elements(in: 15 ..< 19)) == none)
        #expect(Array(tree.elements(in: 30 ..< 30)) == none)
        #expect(Array(tree.elements(in: 0 ... 100)) == all)
    }

    @Test("min and max are the ends, and nil when empty")
    func extremes() {
        let tree: RedBlackTree = [3, 9, 1, 7]
        let smallest: Int? = 1
        let largest: Int? = 9
        #expect(tree.min() == smallest)
        #expect(tree.max() == largest)
        #expect(tree.first == smallest)
        #expect(tree.last == largest)
        #expect(RedBlackTree<Int>().min() == nil)
        #expect(RedBlackTree<Int>().max() == nil)
    }

    @Test("An empty tree has no elements, height 0, no shape and bounds at 0")
    func empty() {
        let tree = RedBlackTree<Int>()
        let zero: Int = 0
        #expect(tree.isEmpty)
        #expect(tree.count == zero)
        #expect(tree.height == zero)
        #expect(Array(tree) == [])
        #expect(tree.lowerBound(1) == zero)
        #expect(!tree.contains(1))
        #expect(BinaryTree(tree) == nil)
        #expect(tree == [])
        #expect(tree.description == "[]")
    }

    @Test("A one-element tree has height 1 and a one-vertex shape")
    func oneElement() throws {
        var tree: RedBlackTree = [42]
        let element: Int = 42
        #expect(tree.count == 1)
        #expect(tree.height == 1)
        #expect(tree[0] == element)
        let shape = try #require(BinaryTree(tree))
        #expect(shape.vertexCount == 1)
        #expect(shape.root == element)
        #expect(shape.height == 0)
        #expect(tree.remove(42) == element)
        #expect(tree.isEmpty)
        #expect(tree.height == 0)
    }

    @Test("remove(at:) removes by rank")
    func removeAtIndex() {
        var tree: RedBlackTree = [10, 20, 30, 40]
        let removed: Int = 30
        #expect(tree.remove(at: 2) == removed)
        let expected: [Int] = [10, 20, 40]
        #expect(Array(tree) == expected)
        let first: Int = 10
        #expect(tree.remove(at: 0) == first)
        let last: Int = 40
        #expect(tree.remove(at: tree.count - 1) == last)
        let rest: [Int] = [20]
        #expect(Array(tree) == rest)
    }

    @Test("Set algebra agrees with Set on two overlapping trees")
    func setAlgebra() {
        let a: RedBlackTree = [1, 2, 3, 4, 5]
        let b: RedBlackTree = [4, 5, 6, 7]
        let union: [Int] = [1, 2, 3, 4, 5, 6, 7]
        let intersection: [Int] = [4, 5]
        let symmetric: [Int] = [1, 2, 3, 6, 7]
        let subtracting: [Int] = [1, 2, 3]
        #expect(Array(a.union(b)) == union)
        #expect(Array(a.intersection(b)) == intersection)
        #expect(Array(a.symmetricDifference(b)) == symmetric)
        #expect(Array(a.subtracting(b)) == subtracting)
        #expect(a.isSubset(of: a.union(b)))
        #expect(!a.isDisjoint(with: b))
        #expect(a.isDisjoint(with: [9, 10]))
        var formed = a
        formed.formUnion(b)
        #expect(Array(formed) == union)
        formed.formIntersection(a)
        #expect(formed == a)
        formed.formSymmetricDifference(b)
        #expect(Array(formed) == symmetric)
        formed.subtract([1, 7])
        let subtracted: [Int] = [2, 3, 6]
        #expect(Array(formed) == subtracted)
        #expect(a.union([]) == a)
        #expect(a.intersection([]).isEmpty)
    }

    @Test("Mutating a copy leaves the original alone", .tags(.copyOnWrite))
    func copyOnWrite() {
        let original: RedBlackTree = [1, 2, 3]
        var copy = original
        copy.insert(4)
        copy.remove(1)
        let originalElements: [Int] = [1, 2, 3]
        let copyElements: [Int] = [2, 3, 4]
        #expect(Array(original) == originalElements)
        #expect(Array(copy) == copyElements)
    }

    @Test("A unique owner mutates its storage in place", .tags(.copyOnWrite))
    func uniqueMutatesInPlace() {
        var tree = RedBlackTree(0 ..< 100)
        let before = tree._core.nodes.withUnsafeBufferPointer { $0.baseAddress }
        tree.remove(50)
        tree.insert(50)
        tree.remove(at: 3)
        let after = tree._core.nodes.withUnsafeBufferPointer { $0.baseAddress }
        #expect(before == after)
    }

    @Test("Trees are equal when their elements are, whatever their shapes", .tags(.conformance))
    func equality() throws {
        var inserted = RedBlackTree<Int>()
        for element in 1 ... 7 {
            inserted.insert(element)
        }
        let built = RedBlackTree(1 ... 7)
        #expect(inserted == built)
        #expect(inserted.hashValue == built.hashValue)
        #expect(built != [1, 2, 3])
        #expect(built != RedBlackTree(2 ... 8))
        let insertedShape = try #require(BinaryTree(inserted))
        let builtShape = try #require(BinaryTree(built))
        #expect(insertedShape.inorder == builtShape.inorder)
    }

    @Test("Codable round-trips the elements as a sorted array", .tags(.conformance))
    func codable() throws {
        let tree: RedBlackTree = [3, 1, 2]
        let data = try JSONEncoder().encode(tree)
        let asArray = try JSONDecoder().decode([Int].self, from: data)
        let sorted: [Int] = [1, 2, 3]
        #expect(asArray == sorted)
        let decoded = try JSONDecoder().decode(RedBlackTree<Int>.self, from: data)
        #expect(decoded == tree)
        let unsorted = Data("[5, 1, 5, 3]".utf8)
        let fromUnsorted = try JSONDecoder().decode(RedBlackTree<Int>.self, from: unsorted)
        let expected: [Int] = [1, 3, 5]
        #expect(Array(fromUnsorted) == expected)
    }

    @Test("The description is the elements written as an array", .tags(.conformance))
    func description() {
        let tree: RedBlackTree = ["b", "a"]
        let expected = #"["a", "b"]"#
        #expect(tree.description == expected)
    }

    @Test("The shape's in-order traversal is the elements, and its height one less", .tags(.fixture))
    func binaryTreeShape() throws {
        var tree = RedBlackTree<Int>()
        for element in [8, 3, 10, 1, 6, 14, 4, 7, 13] {
            tree.insert(element)
        }
        let shape = try #require(BinaryTree(tree))
        #expect(shape.inorder == Array(tree))
        #expect(shape.vertexCount == tree.count)
        #expect(shape.height == tree.height - 1)
    }

    @Test("Both red–black invariants and the height bound hold after every seeded insert and remove", .tags(.randomized))
    func invariantsUnderRandomOperations() {
        var rng = SeededRandomNumberGenerator(seed: 2)
        var tree = RedBlackTree<Int>()
        var reference = Set<Int>()
        for step in 0 ..< 3_000 {
            let element = Int.random(in: 0 ..< 400, using: &rng)
            if Bool.random(using: &rng) || step < 300 {
                tree.insert(element)
                reference.insert(element)
            } else {
                #expect(tree.remove(element) == reference.remove(element))
            }
            // Read the colours from the storage: record 1 is red, 0 black.
            let nodes = tree._core.nodes
            let root = tree._core.root
            #expect(root < 0 || nodes[Int(root)].balance == 0, "a red root at step \(step)")
            var stack: [(slot: Int32, blacks: Int)] = root < 0 ? [] : [(root, 0)]
            var blackHeights = Set<Int>()
            var redUnderRed = 0
            var sizeMismatches = 0
            while let (x, above) = stack.popLast() {
                let node = nodes[Int(x)]
                let blacks = above + (node.balance == 0 ? 1 : 0)
                let leftSize = node.left < 0 ? 0 : Int(nodes[Int(node.left)].size)
                let rightSize = node.right < 0 ? 0 : Int(nodes[Int(node.right)].size)
                if Int(node.size) != leftSize + rightSize + 1 { sizeMismatches += 1 }
                for child in [node.left, node.right] {
                    if child < 0 {
                        blackHeights.insert(blacks)
                    } else {
                        if node.balance == 1 && nodes[Int(child)].balance == 1 { redUnderRed += 1 }
                        stack.append((child, blacks))
                    }
                }
            }
            #expect(redUnderRed == 0, "a red vertex under a red one at step \(step)")
            #expect(blackHeights.count <= 1, "unequal black heights \(blackHeights.sorted()) at step \(step)")
            #expect(sizeMismatches == 0, "a subtree size is wrong at step \(step)")
            #expect(Double(tree.height) <= 2 * log2(Double(tree.count) + 1), "height \(tree.height), \(tree.count) elements")
            if step % 200 == 0 {
                #expect(Array(tree) == reference.sorted())
            }
        }
        #expect(Array(tree) == reference.sorted())
    }

    @Test("A tree built from a sequence satisfies both red–black invariants for every count", .tags(.exhaustive))
    func builtTreesAreRedBlack() {
        for count in 0 ... 70 {
            let tree = RedBlackTree(0 ..< count)
            let nodes = tree._core.nodes
            let root = tree._core.root
            #expect(root < 0 || nodes[Int(root)].balance == 0, "a red root, count \(count)")
            var stack: [(slot: Int32, blacks: Int)] = root < 0 ? [] : [(root, 0)]
            var blackHeights = Set<Int>()
            var redUnderRed = 0
            while let (x, above) = stack.popLast() {
                let node = nodes[Int(x)]
                let blacks = above + (node.balance == 0 ? 1 : 0)
                for child in [node.left, node.right] {
                    if child < 0 {
                        blackHeights.insert(blacks)
                    } else {
                        if node.balance == 1 && nodes[Int(child)].balance == 1 { redUnderRed += 1 }
                        stack.append((child, blacks))
                    }
                }
            }
            #expect(redUnderRed == 0, "count \(count)")
            #expect(blackHeights.count <= 1, "count \(count)")
            var grown = tree
            grown.insert(count)
            grown.remove(0)
            let expected = Array(1 ..< count + 1)
            #expect(Array(grown) == expected, "count \(count)")
        }
    }

    @Test("The checked spellings throw IndexOutOfRange outside the indices")
    func checkedThrows() {
        var tree: RedBlackTree = [1, 2, 3]
        #expect(throws: IndexOutOfRange()) { try tree[checked: 3] }
        #expect(throws: IndexOutOfRange()) { try tree[checked: -1] }
        #expect(throws: IndexOutOfRange()) { try tree.remove(checkedAt: 3) }
        #expect(throws: IndexOutOfRange()) { try tree.remove(checkedAt: -1) }
        let unchanged: [Int] = [1, 2, 3]
        #expect(Array(tree) == unchanged)
        #expect(throws: IndexOutOfRange()) { try RedBlackTree<Int>()[checked: 0] }
    }

    @Test("The checked spellings agree with the plain ones inside the indices")
    func checkedAgrees() throws {
        var tree: RedBlackTree = [1, 2, 3]
        #expect(try tree[checked: 1] == tree[1])
        let removed: Int = 2
        #expect(try tree.remove(checkedAt: 1) == removed)
        let rest: [Int] = [1, 3]
        #expect(Array(tree) == rest)
    }

}
