// Each test is self-contained: it builds its own trees and states its own expectations, so it can
// be copied into another file and still run. Nothing here is shared but the imports. Trees of up to
// a few hundred elements span several levels, because a node holds about 63 Ints; the invariant
// tests read the nodes from `package` storage.

import BTrees
import Foundation
import GrafluentCollectionsTestSupport
import Testing
import Trees

@Suite("BTree: hand-worked cases")
struct BTreeTests {
    @Test("Inserting keeps the elements in ascending order and reports what was inserted")
    func insert() {
        var tree = BTree<Int>()
        for element in [5, 2, 8, 1, 9, 3] {
            #expect(tree.insert(element).inserted)
        }
        let expected: [Int] = [1, 2, 3, 5, 8, 9]
        #expect(Array(tree) == expected)
        #expect(tree.count == 6)
    }

    @Test("Removing every element, in any order, leaves the rest in order each time")
    func remove() {
        var tree = BTree(1 ... 7)
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
        var tree: BTree = [1, 2, 3]
        #expect(tree.remove(4) == nil)
        let expected: [Int] = [1, 2, 3]
        #expect(Array(tree) == expected)
        var empty = BTree<Int>()
        #expect(empty.remove(1) == nil)
    }

    @Test("insert(_:) reports an equal member already present, and update(with:) replaces it")
    func duplicates() {
        var tree: BTree = [1, 2, 3]
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
        var tree = BTree([Tagged(key: 1, tag: "first"), Tagged(key: 0, tag: "zero"), Tagged(key: 1, tag: "second")])
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
        let tree: BTree = [5, 3, 5, 1, 3, 3, 9]
        let expected: [Int] = [1, 3, 5, 9]
        #expect(Array(tree) == expected)
        #expect(tree.count == 4)
        let sorted = BTree(1 ... 100)
        #expect(sorted.count == 100)
        #expect(Array(sorted) == Array(1 ... 100))
    }

    @Test("Indices are ranks: the subscript reads the k-th smallest element")
    func ranks() {
        let tree: BTree = [40, 10, 30, 20, 50]
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
        let tree: BTree = [10, 20, 30, 40]
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
        let tree: BTree = [10, 20, 30, 40, 50]
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
        let tree: BTree = [3, 9, 1, 7]
        let smallest: Int? = 1
        let largest: Int? = 9
        #expect(tree.min() == smallest)
        #expect(tree.max() == largest)
        #expect(tree.first == smallest)
        #expect(tree.last == largest)
        #expect(BTree<Int>().min() == nil)
        #expect(BTree<Int>().max() == nil)
    }

    @Test("An empty tree has no elements, height 0, no shape and bounds at 0")
    func empty() {
        let tree = BTree<Int>()
        let zero: Int = 0
        #expect(tree.isEmpty)
        #expect(tree.count == zero)
        #expect(tree.height == zero)
        #expect(Array(tree) == [])
        #expect(tree.lowerBound(1) == zero)
        #expect(!tree.contains(1))
        #expect(RootedTree(tree) == nil)
        #expect(tree == [])
        #expect(tree.description == "[]")
    }

    @Test("A one-element tree has height 1 and a one-vertex shape")
    func oneElement() throws {
        var tree: BTree = [42]
        let element: Int = 42
        #expect(tree.count == 1)
        #expect(tree.height == 1)
        #expect(tree[0] == element)
        let shape = try #require(RootedTree(tree))
        #expect(shape.vertexCount == 1)
        let root: [Int] = [42]
        #expect(shape.root == root)
        #expect(tree.remove(42) == element)
        #expect(tree.isEmpty)
        #expect(tree.height == 0)
    }

    @Test("remove(at:) removes by rank")
    func removeAtIndex() {
        var tree: BTree = [10, 20, 30, 40]
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
        let a: BTree = [1, 2, 3, 4, 5]
        let b: BTree = [4, 5, 6, 7]
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
        let tree: BTree = [8, 3, 5, 1, 9]
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
        let ofEmpty = BTree<Int>().split(at: 1)
        #expect(ofEmpty.lower.isEmpty)
        #expect(ofEmpty.upper.isEmpty)
    }

    @Test("split(at:) leaves the tree it was called on unchanged", .tags(.copyOnWrite))
    func splitLeavesOriginal() {
        let tree = BTree(1 ... 20)
        let parts = tree.split(at: 15)
        #expect(Array(tree) == Array(1 ... 20))
        #expect(Array(parts.lower) == Array(1 ... 14))
        #expect(Array(parts.upper) == Array(15 ... 20))
    }

    @Test("Both parts of a split are full trees: they insert, remove and index by rank")
    func splitPartsWork() {
        var parts = BTree(1 ... 30).split(at: 11)
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

    @Test("Mutating a copy leaves the original alone", .tags(.copyOnWrite))
    func copyOnWrite() {
        let original: BTree = [1, 2, 3]
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
        var tree = BTree(0 ..< 100)
        let before = ObjectIdentifier(tree._core.root)
        tree.remove(50)
        tree.insert(50)
        tree.remove(at: 3)
        let after = ObjectIdentifier(tree._core.root)
        #expect(before == after)
    }

    @Test("BTrees are equal when their elements are, whatever their shapes", .tags(.conformance))
    func equality() {
        var inserted = BTree<Int>()
        for element in 1 ... 7 {
            inserted.insert(element)
        }
        let built = BTree(1 ... 7)
        #expect(inserted == built)
        #expect(inserted.hashValue == built.hashValue)
        #expect(built != [1, 2, 3])
        #expect(built != BTree(2 ... 8))
        #expect(Array(inserted) == Array(built))
    }

    @Test("Codable round-trips the elements as a sorted array", .tags(.conformance))
    func codable() throws {
        let tree: BTree = [3, 1, 2]
        let data = try JSONEncoder().encode(tree)
        let asArray = try JSONDecoder().decode([Int].self, from: data)
        let sorted: [Int] = [1, 2, 3]
        #expect(asArray == sorted)
        let decoded = try JSONDecoder().decode(BTree<Int>.self, from: data)
        #expect(decoded == tree)
        let unsorted = Data("[5, 1, 5, 3]".utf8)
        let fromUnsorted = try JSONDecoder().decode(BTree<Int>.self, from: unsorted)
        let expected: [Int] = [1, 3, 5]
        #expect(Array(fromUnsorted) == expected)
    }

    @Test("The description is the elements written as an array", .tags(.conformance))
    func description() {
        let tree: BTree = ["b", "a"]
        let expected = #"["a", "b"]"#
        #expect(tree.description == expected)
    }

    @Test("The shape has a vertex per node, its keys in order, and the leaves at one depth", .tags(.fixture))
    func rootedTreeShape() throws {
        let tree = BTree(0 ..< 1_000)
        let shape = try #require(RootedTree(tree))
        let flattened = shape.preorder.flatMap { $0 }.sorted()
        #expect(flattened == Array(0 ..< 1_000))
        let depths = Set(shape.preorder.filter { shape.children(of: $0).isEmpty }.map { shape.depth(of: $0) })
        #expect(depths.count == 1)
        #expect(depths.first == tree.height - 1)
        // Each node's children lie between its keys, in key order.
        for vertex in shape.preorder {
            let children = Array(shape.children(of: vertex))
            guard !children.isEmpty else { continue }
            #expect(children.count == vertex.count + 1)
            for (index, child) in children.enumerated() {
                if index > 0 { #expect(child.first! > vertex[index - 1]) }
                if index < vertex.count { #expect(child.last! < vertex[index]) }
            }
        }
    }

    @Test("A mutated copy shares every node off the changed path with the original", .tags(.copyOnWrite))
    func copiesShareNodes() {
        let original = BTree(0 ..< 10_000)
        var copy = original
        copy.insert(-1)
        let originalChildren = original._core.root.header.children.map(ObjectIdentifier.init)
        let copyChildren = copy._core.root.header.children.map(ObjectIdentifier.init)
        #expect(ObjectIdentifier(original._core.root) != ObjectIdentifier(copy._core.root))
        // Only the leftmost child, on the path to the new smallest element, was copied.
        let shared = zip(originalChildren, copyChildren).filter { $0 == $1 }.count
        #expect(originalChildren.count == copyChildren.count)
        #expect(shared == originalChildren.count - 1)
        #expect(Array(original) == Array(0 ..< 10_000))
        #expect(Array(copy) == Array(-1 ..< 10_000))
    }

    @Test("Inserting an element already in a full root leaf splits nothing")
    func insertExistingIntoFullNode() {
        let maxElements = 2 * _BTreeCore<Int, Void>.minimumDegree - 1
        var tree = BTree<Int>()
        for element in 0 ..< maxElements {
            tree.insert(element)
        }
        let root = ObjectIdentifier(tree._core.root)
        let present = 0
        let leafHeight = 1
        #expect(tree._core.root.elementCount == maxElements)
        #expect(!tree.insert(present).inserted)
        #expect(tree.height == leafHeight)
        #expect(ObjectIdentifier(tree._core.root) == root)
    }

    @Test("Removing and reinserting one element allocates no node after the first pair")
    func removeInsertSteadyState() {
        var tree = BTree<Int>()
        for element in 0 ..< 200 {
            tree.insert(element)
        }
        func nodes(_ tree: BTree<Int>) -> Set<ObjectIdentifier> {
            var found = Set<ObjectIdentifier>()
            var stack = [tree._core.root]
            while let node = stack.popLast() {
                found.insert(ObjectIdentifier(node))
                stack.append(contentsOf: node.header.children)
            }
            return found
        }
        let element = 0
        tree.remove(element)
        tree.insert(element)
        let settled = nodes(tree)
        for _ in 0 ..< 50 {
            tree.remove(element)
            tree.insert(element)
        }
        #expect(nodes(tree) == settled)
        #expect(Array(tree) == Array(0 ..< 200))
    }

    @Test("Node sizes, key order, leaf depth and subtree counts hold after every seeded operation", .tags(.randomized))
    func invariantsUnderRandomOperations() {
        var rng = SeededRandomNumberGenerator(seed: 5)
        var tree = BTree<Int>()
        var reference = Set<Int>()
        let maxElements = 2 * _BTreeCore<Int, Void>.minimumDegree - 1
        let minElements = _BTreeCore<Int, Void>.minimumDegree - 1
        for step in 0 ..< 6_000 {
            let element = Int.random(in: 0 ..< 1_500, using: &rng)
            if Int.random(in: 0 ..< 10, using: &rng) < 6 || step < 1_500 {
                #expect(tree.insert(element).inserted == reference.insert(element).inserted)
            } else {
                #expect(tree.remove(element) == reference.remove(element))
            }
            guard step % 25 == 0 else { continue }
            var stack: [(node: _BTreeNode<Int, Void>, depth: Int, low: Int?, high: Int?)] = [(tree._core.root, 0, nil, nil)]
            var leafDepths = Set<Int>()
            var sizeViolations = 0
            var orderViolations = 0
            var countMismatches = 0
            while let (node, depth, low, high) = stack.popLast() {
                let keys = (0 ..< node.elementCount).map { node.key(at: $0) }
                let isRoot = depth == 0
                if keys.count > maxElements || (!isRoot && keys.count < minElements) { sizeViolations += 1 }
                if keys != keys.sorted() || Set(keys).count != keys.count { orderViolations += 1 }
                if let low, let first = keys.first, !(low < first) { orderViolations += 1 }
                if let high, let last = keys.last, !(last < high) { orderViolations += 1 }
                let children = node.header.children
                if children.isEmpty {
                    leafDepths.insert(depth)
                    if node.header.subtreeCount != keys.count { countMismatches += 1 }
                    continue
                }
                if children.count != keys.count + 1 { sizeViolations += 1 }
                let below = children.reduce(0) { $0 + $1.header.subtreeCount }
                if node.header.subtreeCount != keys.count + below { countMismatches += 1 }
                for (index, child) in children.enumerated() {
                    stack.append((child, depth + 1, index == 0 ? low : keys[index - 1], index == keys.count ? high : keys[index]))
                }
            }
            #expect(sizeViolations == 0, "a node outside its size bounds at step \(step)")
            #expect(orderViolations == 0, "keys out of order at step \(step)")
            #expect(leafDepths.count <= 1, "leaves at depths \(leafDepths.sorted()) at step \(step)")
            #expect(countMismatches == 0, "a subtree count is wrong at step \(step)")
            #expect(tree.count == reference.count)
        }
        #expect(Array(tree) == reference.sorted())
    }

    @Test("A tree built from a sequence keeps every node within its size bounds, for every count", .tags(.exhaustive))
    func builtTreesAreBTrees() {
        let maxElements = 2 * _BTreeCore<Int, Void>.minimumDegree - 1
        let minElements = _BTreeCore<Int, Void>.minimumDegree - 1
        for count in Array(0 ... 300) + [4_095, 4_096, 4_097, 300_000] {
            let tree = BTree(0 ..< count)
            var stack: [(node: _BTreeNode<Int, Void>, depth: Int)] = [(tree._core.root, 0)]
            var leafDepths = Set<Int>()
            var sizeViolations = 0
            while let (node, depth) = stack.popLast() {
                let elements = node.elementCount
                if elements > maxElements || (depth > 0 && elements < minElements) { sizeViolations += 1 }
                if node.header.children.isEmpty {
                    leafDepths.insert(depth)
                } else {
                    if node.header.children.count != elements + 1 { sizeViolations += 1 }
                    for child in node.header.children { stack.append((child, depth + 1)) }
                }
            }
            #expect(sizeViolations == 0, "count \(count)")
            #expect(leafDepths.count == 1, "count \(count)")
            #expect(tree.count == count, "count \(count)")
            if count <= 300 {
                #expect(Array(tree) == Array(0 ..< count), "count \(count)")
                for rank in 0 ..< count {
                    #expect(tree[rank] == rank, "count \(count)")
                }
            }
        }
    }

    @Test("Removing in ascending, descending and scattered order merges and borrows correctly")
    func removalOrders() {
        let count = 2_000
        for order in [Array(0 ..< count), Array((0 ..< count).reversed()), (0 ..< count).map { ($0 * 7_919) % count }] {
            var tree = BTree(0 ..< count)
            var remaining = Set(0 ..< count)
            for (step, element) in order.enumerated() {
                let removed: Int? = element
                #expect(tree.remove(element) == removed)
                remaining.remove(element)
                if step % 97 == 0 {
                    #expect(Array(tree) == remaining.sorted())
                }
            }
            #expect(tree.isEmpty)
            #expect(tree.height == 0)
        }
    }

    @Test("popFirst and popLast remove the ends, and return nil when empty")
    func popEnds() {
        var tree = BTree(0 ..< 500)
        let first: Int? = 0
        let last: Int? = 499
        #expect(tree.popFirst() == first)
        #expect(tree.popLast() == last)
        #expect(Array(tree) == Array(1 ..< 499))
        var empty = BTree<Int>()
        #expect(empty.popFirst() == nil)
        #expect(empty.popLast() == nil)
    }

    @Test("The checked spellings throw IndexOutOfRange outside the indices")
    func checkedThrows() {
        var tree: BTree = [1, 2, 3]
        #expect(throws: IndexOutOfRange()) { try tree[checked: 3] }
        #expect(throws: IndexOutOfRange()) { try tree[checked: -1] }
        #expect(throws: IndexOutOfRange()) { try tree.remove(checkedAt: 3) }
        #expect(throws: IndexOutOfRange()) { try tree.remove(checkedAt: -1) }
        let unchanged: [Int] = [1, 2, 3]
        #expect(Array(tree) == unchanged)
        #expect(throws: IndexOutOfRange()) { try BTree<Int>()[checked: 0] }
    }

    @Test("The checked spellings agree with the plain ones inside the indices")
    func checkedAgrees() throws {
        var tree: BTree = [1, 2, 3]
        #expect(try tree[checked: 1] == tree[1])
        let removed: Int = 2
        #expect(try tree.remove(checkedAt: 1) == removed)
        let rest: [Int] = [1, 3]
        #expect(Array(tree) == rest)
    }

}
