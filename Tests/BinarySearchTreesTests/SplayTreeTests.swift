// Each test is self-contained: it builds its own trees and states its own expectations, so it can
// be copied into another file and still run. Nothing here is shared but the imports. The tests
// check a splay tree's elements, its search-tree order and where splaying leaves an element (at
// the root), not the rest of its shape.

import BinarySearchTrees
import Foundation
import GrafluentCollectionsTestSupport
import Testing
import Trees

@Suite("SplayTree: hand-worked cases")
struct SplayTreeTests {
    @Test("Inserting keeps the elements in ascending order and reports what was inserted")
    func insert() {
        var tree = SplayTree<Int>()
        for element in [5, 2, 8, 1, 9, 3] {
            #expect(tree.insert(element).inserted)
        }
        let expected: [Int] = [1, 2, 3, 5, 8, 9]
        #expect(Array(tree) == expected)
        #expect(tree.count == 6)
    }

    @Test("Iterating a tree higher than 64 visits every element in ascending order")
    func iterateDeepTree() {
        var tree = SplayTree<Int>()
        let count = 200
        for element in 0 ..< count {
            tree.insert(element)
        }
        let minimumHeight = 65
        let expected = Array(0 ..< count)
        #expect(tree.height >= minimumHeight)
        #expect(Array(tree) == expected)
    }

    @Test("Removing a leaf, a vertex with one child and the root each leaves the rest in order")
    func remove() {
        var tree = SplayTree(1 ... 7)
        for element in [7, 1, 4, 2, 6, 3, 5] {
            let removed: Int? = element
            #expect(tree.remove(element) == removed)
            #expect(!tree.contains(element))
        }
        #expect(tree.isEmpty)
        #expect(tree.height == 0)
    }

    @Test("Removing an absent element changes nothing and returns nil")
    func removeAbsent() {
        var tree: SplayTree = [1, 2, 3]
        #expect(tree.remove(4) == nil)
        let expected: [Int] = [1, 2, 3]
        #expect(Array(tree) == expected)
        var empty = SplayTree<Int>()
        #expect(empty.remove(1) == nil)
    }

    @Test("insert(_:) reports an equal member already present, and update(with:) replaces it")
    func duplicates() {
        var tree: SplayTree = [1, 2, 3]
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
        var tree = SplayTree([Tagged(key: 1, tag: "first"), Tagged(key: 0, tag: "zero"), Tagged(key: 1, tag: "second")])
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
        let tree: SplayTree = [5, 3, 5, 1, 3, 3, 9]
        let expected: [Int] = [1, 3, 5, 9]
        #expect(Array(tree) == expected)
        #expect(tree.count == 4)
        let sorted = SplayTree(1 ... 100)
        #expect(sorted.count == 100)
        #expect(Array(sorted) == Array(1 ... 100))
    }

    @Test("Indices are ranks: the subscript reads the k-th smallest element")
    func ranks() {
        let tree: SplayTree = [40, 10, 30, 20, 50]
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
        let tree: SplayTree = [10, 20, 30, 40]
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
        let tree: SplayTree = [10, 20, 30, 40, 50]
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
        let tree: SplayTree = [3, 9, 1, 7]
        let smallest: Int? = 1
        let largest: Int? = 9
        #expect(tree.min() == smallest)
        #expect(tree.max() == largest)
        #expect(tree.first == smallest)
        #expect(tree.last == largest)
        #expect(SplayTree<Int>().min() == nil)
        #expect(SplayTree<Int>().max() == nil)
    }

    @Test("An empty tree has no elements, height 0, no shape and bounds at 0")
    func empty() {
        let tree = SplayTree<Int>()
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
        var tree: SplayTree = [42]
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
        var tree: SplayTree = [10, 20, 30, 40]
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
        let a: SplayTree = [1, 2, 3, 4, 5]
        let b: SplayTree = [4, 5, 6, 7]
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

    @Test("split(at:) puts the elements below the split point in lower and the rest in upper")
    func split() {
        let tree: SplayTree = [8, 3, 5, 1, 9]
        let atPresent = tree.split(at: 5)
        let lower: [Int] = [1, 3]
        let upper: [Int] = [5, 8, 9]
        #expect(Array(atPresent.lower) == lower)
        #expect(Array(atPresent.upper) == upper)
        let atAbsent = tree.split(at: 4)
        #expect(Array(atAbsent.lower) == lower)
        #expect(Array(atAbsent.upper) == upper)
        let all: [Int] = [1, 3, 5, 8, 9]
        let belowAll = tree.split(at: 0)
        #expect(belowAll.lower.isEmpty)
        #expect(Array(belowAll.upper) == all)
        let aboveAll = tree.split(at: 10)
        #expect(Array(aboveAll.lower) == all)
        #expect(aboveAll.upper.isEmpty)
        let ofEmpty = SplayTree<Int>().split(at: 1)
        #expect(ofEmpty.lower.isEmpty)
        #expect(ofEmpty.upper.isEmpty)
    }

    @Test("split(at:) leaves the tree it was called on unchanged", .tags(.copyOnWrite))
    func splitLeavesOriginal() {
        let tree = SplayTree(1 ... 20)
        let parts = tree.split(at: 15)
        #expect(Array(tree) == Array(1 ... 20))
        #expect(Array(parts.lower) == Array(1 ... 14))
        #expect(Array(parts.upper) == Array(15 ... 20))
    }

    @Test("Both parts of a split are full trees: they insert, remove and index by rank")
    func splitPartsWork() {
        var parts = SplayTree(1 ... 30).split(at: 11)
        parts.lower.insert(0)
        parts.lower.remove(5)
        parts.upper.insert(31)
        parts.upper.remove(20)
        let lower: [Int] = [0, 1, 2, 3, 4, 6, 7, 8, 9, 10]
        #expect(Array(parts.lower) == lower)
        #expect(Array(parts.upper) == Array(11 ... 19) + Array(21 ... 31))
        let tenth: Int = 10
        #expect(parts.lower[9] == tenth)
        let eleventh: Int = 11
        #expect(parts.upper[0] == eleventh)
    }

    @Test("join(_:) adds a tree whose elements lie all above or all below")
    func join() throws {
        var low: SplayTree = [1, 2, 3]
        try low.join([7, 8])
        let joinedAbove: [Int] = [1, 2, 3, 7, 8]
        #expect(Array(low) == joinedAbove)
        var high: SplayTree = [7, 8]
        try high.join([1, 2, 3])
        #expect(Array(high) == joinedAbove)
        var empty = SplayTree<Int>()
        try empty.join([4, 5])
        let joinedIntoEmpty: [Int] = [4, 5]
        #expect(Array(empty) == joinedIntoEmpty)
        var unchanged: SplayTree = [4, 5]
        try unchanged.join([])
        #expect(Array(unchanged) == joinedIntoEmpty)
    }

    @Test("join(_:) throws OverlappingKeys when the elements interleave or meet, and changes nothing")
    func joinOverlapping() {
        var tree: SplayTree = [1, 5, 9]
        let interleaved: SplayTree = [3, 4]
        #expect(throws: OverlappingKeys()) { try tree.join(interleaved) }
        let sharing: SplayTree = [9, 10]
        #expect(throws: OverlappingKeys()) { try tree.join(sharing) }
        let unchanged: [Int] = [1, 5, 9]
        #expect(Array(tree) == unchanged)
    }

    @Test("Splitting and joining the parts gives back the tree, at every split point", .tags(.exhaustive))
    func splitJoinRoundTrip() throws {
        let tree = SplayTree((0 ..< 40).map { $0 * 2 })
        for point in -1 ... 80 {
            let parts = tree.split(at: point)
            #expect(parts.lower.allSatisfy { $0 < point }, "split at \(point)")
            #expect(parts.upper.allSatisfy { $0 >= point }, "split at \(point)")
            var rejoined = parts.lower
            try rejoined.join(parts.upper)
            #expect(rejoined == tree, "split at \(point)")
            var reversed = parts.upper
            try reversed.join(parts.lower)
            #expect(reversed == tree, "split at \(point)")
        }
    }

    @Test("Mutating a copy leaves the original alone", .tags(.copyOnWrite))
    func copyOnWrite() throws {
        let original: SplayTree = [1, 2, 3]
        var copy = original
        copy.insert(4)
        copy.remove(1)
        try copy.join([10, 11])
        let originalElements: [Int] = [1, 2, 3]
        let copyElements: [Int] = [2, 3, 4, 10, 11]
        #expect(Array(original) == originalElements)
        #expect(Array(copy) == copyElements)
    }

    @Test("A unique owner mutates its storage in place", .tags(.copyOnWrite))
    func uniqueMutatesInPlace() {
        var tree = SplayTree(0 ..< 100)
        let before = tree._core.nodes.withUnsafeBufferPointer { $0.baseAddress }
        tree.remove(50)
        tree.insert(50)
        tree.remove(at: 3)
        let after = tree._core.nodes.withUnsafeBufferPointer { $0.baseAddress }
        #expect(before == after)
    }

    @Test("Splay trees are equal when their elements are, whatever their shapes", .tags(.conformance))
    func equality() throws {
        var inserted = SplayTree<Int>()
        for element in 1 ... 7 {
            inserted.insert(element)
        }
        let built = SplayTree(1 ... 7)
        #expect(inserted == built)
        #expect(inserted.hashValue == built.hashValue)
        #expect(built != [1, 2, 3])
        #expect(built != SplayTree(2 ... 8))
        let insertedShape = try #require(BinaryTree(inserted))
        let builtShape = try #require(BinaryTree(built))
        #expect(insertedShape.inorder == builtShape.inorder)
    }

    @Test("Codable round-trips the elements as a sorted array", .tags(.conformance))
    func codable() throws {
        let tree: SplayTree = [3, 1, 2]
        let data = try JSONEncoder().encode(tree)
        let asArray = try JSONDecoder().decode([Int].self, from: data)
        let sorted: [Int] = [1, 2, 3]
        #expect(asArray == sorted)
        let decoded = try JSONDecoder().decode(SplayTree<Int>.self, from: data)
        #expect(decoded == tree)
        let unsorted = Data("[5, 1, 5, 3]".utf8)
        let fromUnsorted = try JSONDecoder().decode(SplayTree<Int>.self, from: unsorted)
        let expected: [Int] = [1, 3, 5]
        #expect(Array(fromUnsorted) == expected)
    }

    @Test("The description is the elements written as an array", .tags(.conformance))
    func description() {
        let tree: SplayTree = ["b", "a"]
        let expected = #"["a", "b"]"#
        #expect(tree.description == expected)
    }

    @Test("The shape's in-order traversal is the elements, and its height one less", .tags(.fixture))
    func binaryTreeShape() throws {
        var tree = SplayTree<Int>()
        for element in [8, 3, 10, 1, 6, 14, 4, 7, 13] {
            tree.insert(element)
        }
        let shape = try #require(BinaryTree(tree))
        #expect(shape.inorder == Array(tree))
        #expect(shape.vertexCount == tree.count)
        #expect(shape.height == tree.height - 1)
    }

    @Test("access(_:) returns the element and moves it to the root; an absent one returns nil")
    func accessSplays() throws {
        var tree = SplayTree(1 ... 15)
        for element in [1, 15, 8, 3, 3, 12] {
            let accessed: Int? = element
            #expect(tree.access(element) == accessed)
            let shape = try #require(BinaryTree(tree))
            #expect(shape.root == element)
        }
        #expect(tree.access(100) == nil)
        let largest: Int = 15
        let shape = try #require(BinaryTree(tree))
        #expect(shape.root == largest)
        #expect(Array(tree) == Array(1 ... 15))
    }

    @Test("An inserted element, or the equal one already present, ends at the root")
    func insertSplays() throws {
        var tree: SplayTree = [10, 20, 30, 40]
        tree.insert(25)
        let inserted: Int = 25
        #expect(try #require(BinaryTree(tree)).root == inserted)
        tree.insert(10)
        let present: Int = 10
        #expect(try #require(BinaryTree(tree)).root == present)
        let expected: [Int] = [10, 20, 25, 30, 40]
        #expect(Array(tree) == expected)
    }

    @Test("Reads leave the shape as it is: contains, bounds, subscripts and iteration don't splay")
    func readsDontSplay() throws {
        let tree = SplayTree(1 ... 31)
        let before = try #require(BinaryTree(tree))
        _ = tree.contains(1)
        _ = tree.contains(100)
        _ = tree.lowerBound(17)
        _ = tree[3]
        _ = tree.firstIndex(of: 9)
        _ = Array(tree)
        let after = try #require(BinaryTree(tree))
        #expect(Array(before.preorder) == Array(after.preorder))
    }

    @Test("Inserting in ascending order leaves a path, which reads still answer correctly")
    func ascendingInsertsMakeAPath() {
        var tree = SplayTree<Int>()
        for element in 0 ..< 200 {
            tree.insert(element)
        }
        let path: Int = 200
        #expect(tree.height == path)
        #expect(tree.contains(0))
        let first: Int = 0
        #expect(tree[0] == first)
        #expect(Array(tree) == Array(0 ..< 200))
        tree.access(0)
        #expect(tree.height < 200)
    }

    @Test("BST order and subtree sizes hold, and the element splayed is the root, after every seeded operation", .tags(.randomized))
    func invariantsUnderRandomOperations() throws {
        var rng = SeededRandomNumberGenerator(seed: 5)
        var tree = SplayTree<Int>()
        var reference = Set<Int>()
        for step in 0 ..< 3_000 {
            let element = Int.random(in: 0 ..< 400, using: &rng)
            var expectedRoot: Int?
            switch Int.random(in: 0 ..< 20, using: &rng) {
            case 0:
                // Split and join back, in either order.
                let parts = tree.split(at: element)
                if Bool.random(using: &rng) {
                    tree = parts.lower
                    try tree.join(parts.upper)
                } else {
                    tree = parts.upper
                    try tree.join(parts.lower)
                }
            case 1 ... 4:
                #expect(tree.access(element) == (reference.contains(element) ? element : nil))
                if reference.contains(element) { expectedRoot = element }
            case 5 ... 12 where step >= 300:
                #expect(tree.remove(element) == reference.remove(element))
            default:
                #expect(tree.insert(element).inserted == reference.insert(element).inserted)
                expectedRoot = element
            }
            let nodes = tree._core.nodes
            let root = tree._core.root
            if let expectedRoot {
                #expect(root >= 0 && nodes[Int(root)].key == expectedRoot, "the root at step \(step)")
            }
            var stack: [(slot: Int32, low: Int?, high: Int?)] = root < 0 ? [] : [(root, nil, nil)]
            var visited = 0
            var orderViolations = 0
            var sizeMismatches = 0
            while let (x, low, high) = stack.popLast() {
                visited += 1
                let node = nodes[Int(x)]
                if let low, !(low < node.key) { orderViolations += 1 }
                if let high, !(node.key < high) { orderViolations += 1 }
                let leftSize = node.left < 0 ? 0 : Int(nodes[Int(node.left)].size)
                let rightSize = node.right < 0 ? 0 : Int(nodes[Int(node.right)].size)
                if Int(node.size) != leftSize + rightSize + 1 { sizeMismatches += 1 }
                if node.left >= 0 { stack.append((node.left, low, node.key)) }
                if node.right >= 0 { stack.append((node.right, node.key, high)) }
            }
            #expect(visited == tree.count, "unreachable vertices at step \(step)")
            #expect(orderViolations == 0, "a key out of search-tree order at step \(step)")
            #expect(sizeMismatches == 0, "a subtree size is wrong at step \(step)")
            if step % 200 == 0 {
                #expect(Array(tree) == reference.sorted())
            }
        }
        #expect(Array(tree) == reference.sorted())
    }

    @Test("A tree built from a sequence is balanced, with right sizes, for every count", .tags(.exhaustive))
    func builtTreesAreBalanced() {
        for count in 0 ... 70 {
            let tree = SplayTree(0 ..< count)
            let nodes = tree._core.nodes
            let root = tree._core.root
            var stack: [Int32] = root < 0 ? [] : [root]
            var visited = 0
            var sizeMismatches = 0
            while let x = stack.popLast() {
                visited += 1
                let node = nodes[Int(x)]
                let leftSize = node.left < 0 ? 0 : Int(nodes[Int(node.left)].size)
                let rightSize = node.right < 0 ? 0 : Int(nodes[Int(node.right)].size)
                if Int(node.size) != leftSize + rightSize + 1 { sizeMismatches += 1 }
                for child in [node.left, node.right] where child >= 0 {
                    stack.append(child)
                }
            }
            let bitWidth = Int.bitWidth - count.leadingZeroBitCount
            #expect(visited == count, "count \(count)")
            #expect(sizeMismatches == 0, "count \(count)")
            #expect(tree.height == bitWidth, "count \(count)")
            #expect(Array(tree) == Array(0 ..< count), "count \(count)")
            for rank in 0 ..< count {
                #expect(tree[rank] == rank, "count \(count)")
            }
        }
    }

    @Test("The checked spellings throw IndexOutOfRange outside the indices")
    func checkedThrows() {
        var tree: SplayTree = [1, 2, 3]
        #expect(throws: IndexOutOfRange()) { try tree[checked: 3] }
        #expect(throws: IndexOutOfRange()) { try tree[checked: -1] }
        #expect(throws: IndexOutOfRange()) { try tree.remove(checkedAt: 3) }
        #expect(throws: IndexOutOfRange()) { try tree.remove(checkedAt: -1) }
        let unchanged: [Int] = [1, 2, 3]
        #expect(Array(tree) == unchanged)
        #expect(throws: IndexOutOfRange()) { try SplayTree<Int>()[checked: 0] }
    }

    @Test("The checked spellings agree with the plain ones inside the indices")
    func checkedAgrees() throws {
        var tree: SplayTree = [1, 2, 3]
        #expect(try tree[checked: 1] == tree[1])
        let removed: Int = 2
        #expect(try tree.remove(checkedAt: 1) == removed)
        let rest: [Int] = [1, 3]
        #expect(Array(tree) == rest)
    }

    @Test("The plain spellings trap outside the indices", .tags(.precondition))
    func plainTraps() async {
        await #expect(processExitsWith: .failure) {
            let tree: SplayTree = [1, 2, 3]
            _ = tree[3]
        }
        await #expect(processExitsWith: .failure) {
            let tree: SplayTree = [1, 2, 3]
            _ = tree[-1]
        }
        await #expect(processExitsWith: .failure) {
            var tree: SplayTree = [1, 2, 3]
            tree.remove(at: 3)
        }
        await #expect(processExitsWith: .failure) {
            var tree = SplayTree<Int>()
            tree.remove(at: 0)
        }
    }
}
