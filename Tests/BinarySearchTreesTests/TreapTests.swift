// Each test is self-contained: it builds its own treaps and states its own expectations, so it can
// be copied into another file and still run. Nothing here is shared but the imports. A treap's
// shape depends on its random priorities, so the tests check its elements and its invariants, not
// a particular shape.

import BinarySearchTrees
import Foundation
import GrafluentCollectionsTestSupport
import Testing
import Trees

@Suite("Treap: hand-worked cases")
struct TreapTests {
    @Test("Inserting keeps the elements in ascending order and reports what was inserted")
    func insert() {
        var rng = SeededRandomNumberGenerator(seed: 1)
        var treap = Treap<Int>(using: &rng)
        for element in [5, 2, 8, 1, 9, 3] {
            #expect(treap.insert(element).inserted)
        }
        let expected: [Int] = [1, 2, 3, 5, 8, 9]
        #expect(Array(treap) == expected)
        #expect(treap.count == 6)
    }

    @Test("Removing a leaf, a vertex with one child and the root each leaves the rest in order")
    func remove() {
        var rng = SeededRandomNumberGenerator(seed: 2)
        var treap = Treap(1 ... 7, using: &rng)
        for element in [7, 1, 4, 2, 6, 3, 5] {
            let removed: Int? = element
            #expect(treap.remove(element) == removed)
            #expect(!treap.contains(element))
        }
        #expect(treap.isEmpty)
        #expect(treap.height == 0)
    }

    @Test("Removing an absent element changes nothing and returns nil")
    func removeAbsent() {
        var treap: Treap = [1, 2, 3]
        #expect(treap.remove(4) == nil)
        let expected: [Int] = [1, 2, 3]
        #expect(Array(treap) == expected)
        var empty = Treap<Int>()
        #expect(empty.remove(1) == nil)
    }

    @Test("insert(_:) reports an equal member already present, and update(with:) replaces it")
    func duplicates() {
        var treap: Treap = [1, 2, 3]
        let again = treap.insert(2)
        #expect(!again.inserted)
        #expect(again.memberAfterInsert == 2)
        #expect(treap.count == 3)
        let fresh = treap.insert(4)
        #expect(fresh.inserted)
        #expect(fresh.memberAfterInsert == 4)
        let replaced: Int? = 2
        #expect(treap.update(with: 2) == replaced)
        #expect(treap.update(with: 9) == nil)
        let expected: [Int] = [1, 2, 3, 4, 9]
        #expect(Array(treap) == expected)
    }

    @Test("Of equal elements, init keeps the first, update(with:) the new one, insert the old one")
    func equalElementsKeepTheirIdentity() {
        struct Tagged: Comparable {
            var key: Int
            var tag: String
            static func < (a: Tagged, b: Tagged) -> Bool { a.key < b.key }
            static func == (a: Tagged, b: Tagged) -> Bool { a.key == b.key }
        }
        var treap = Treap([Tagged(key: 1, tag: "first"), Tagged(key: 0, tag: "zero"), Tagged(key: 1, tag: "second")])
        let tags = treap.map(\.tag)
        let expectedTags: [String] = ["zero", "first"]
        #expect(tags == expectedTags)
        treap.insert(Tagged(key: 1, tag: "inserted"))
        #expect(treap[1].tag == "first")
        treap.update(with: Tagged(key: 1, tag: "updated"))
        #expect(treap[1].tag == "updated")
    }

    @Test("A literal or sequence with duplicates holds each element once, in ascending order")
    func initDeduplicates() {
        let treap: Treap = [5, 3, 5, 1, 3, 3, 9]
        let expected: [Int] = [1, 3, 5, 9]
        #expect(Array(treap) == expected)
        #expect(treap.count == 4)
        let sorted = Treap(1 ... 100)
        #expect(sorted.count == 100)
        #expect(Array(sorted) == Array(1 ... 100))
    }

    @Test("Indices are ranks: the subscript reads the k-th smallest element")
    func ranks() {
        let treap: Treap = [40, 10, 30, 20, 50]
        let expected: [Int] = [10, 20, 30, 40, 50]
        for (index, element) in expected.enumerated() {
            #expect(treap[index] == element)
        }
        let index: Int? = 2
        #expect(treap.firstIndex(of: 30) == index)
        #expect(treap.lastIndex(of: 30) == index)
        #expect(treap.firstIndex(of: 35) == nil)
        #expect(treap.contains(40))
        #expect(!treap.contains(45))
        let descending: [Int] = [50, 40, 30, 20, 10]
        #expect(Array(treap.reversed()) == descending)
    }

    @Test("lowerBound and upperBound bracket an element, present or not")
    func bounds() {
        let treap: Treap = [10, 20, 30, 40]
        let zero: Int = 0
        let one: Int = 1
        let two: Int = 2
        #expect(treap.lowerBound(20) == one)
        #expect(treap.upperBound(20) == two)
        #expect(treap.lowerBound(25) == two)
        #expect(treap.upperBound(25) == two)
        #expect(treap.lowerBound(5) == zero)
        #expect(treap.upperBound(5) == zero)
        #expect(treap.lowerBound(45) == treap.endIndex)
        #expect(treap.upperBound(40) == treap.endIndex)
    }

    @Test("elements(in:) is the elements in a half-open or closed range of values")
    func elementsInRange() {
        let treap: Treap = [10, 20, 30, 40, 50]
        let halfOpen: [Int] = [20, 30]
        let closed: [Int] = [20, 30, 40]
        let none: [Int] = []
        let all: [Int] = [10, 20, 30, 40, 50]
        #expect(Array(treap.elements(in: 20 ..< 40)) == halfOpen)
        #expect(Array(treap.elements(in: 20 ... 40)) == closed)
        #expect(Array(treap.elements(in: 15 ..< 19)) == none)
        #expect(Array(treap.elements(in: 30 ..< 30)) == none)
        #expect(Array(treap.elements(in: 0 ... 100)) == all)
    }

    @Test("min and max are the ends, and nil when empty")
    func extremes() {
        let treap: Treap = [3, 9, 1, 7]
        let smallest: Int? = 1
        let largest: Int? = 9
        #expect(treap.min() == smallest)
        #expect(treap.max() == largest)
        #expect(treap.first == smallest)
        #expect(treap.last == largest)
        #expect(Treap<Int>().min() == nil)
        #expect(Treap<Int>().max() == nil)
    }

    @Test("An empty treap has no elements, height 0, no shape and bounds at 0")
    func empty() {
        let treap = Treap<Int>()
        let zero: Int = 0
        #expect(treap.isEmpty)
        #expect(treap.count == zero)
        #expect(treap.height == zero)
        #expect(Array(treap) == [])
        #expect(treap.lowerBound(1) == zero)
        #expect(!treap.contains(1))
        #expect(BinaryTree(treap) == nil)
        #expect(treap == [])
        #expect(treap.description == "[]")
    }

    @Test("A one-element treap has height 1 and a one-vertex shape")
    func oneElement() throws {
        var treap: Treap = [42]
        let element: Int = 42
        #expect(treap.count == 1)
        #expect(treap.height == 1)
        #expect(treap[0] == element)
        let shape = try #require(BinaryTree(treap))
        #expect(shape.vertexCount == 1)
        #expect(shape.root == element)
        #expect(shape.height == 0)
        #expect(treap.remove(42) == element)
        #expect(treap.isEmpty)
        #expect(treap.height == 0)
    }

    @Test("remove(at:) removes by rank")
    func removeAtIndex() {
        var treap: Treap = [10, 20, 30, 40]
        let removed: Int = 30
        #expect(treap.remove(at: 2) == removed)
        let expected: [Int] = [10, 20, 40]
        #expect(Array(treap) == expected)
        let first: Int = 10
        #expect(treap.remove(at: 0) == first)
        let last: Int = 40
        #expect(treap.remove(at: treap.count - 1) == last)
        let rest: [Int] = [20]
        #expect(Array(treap) == rest)
    }

    @Test("Set algebra agrees with Set on two overlapping treaps")
    func setAlgebra() {
        let a: Treap = [1, 2, 3, 4, 5]
        let b: Treap = [4, 5, 6, 7]
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
        let treap: Treap = [8, 3, 5, 1, 9]
        let atPresent = treap.split(at: 5)
        let lower: [Int] = [1, 3]
        let upper: [Int] = [5, 8, 9]
        #expect(Array(atPresent.lower) == lower)
        #expect(Array(atPresent.upper) == upper)
        let atAbsent = treap.split(at: 4)
        #expect(Array(atAbsent.lower) == lower)
        #expect(Array(atAbsent.upper) == upper)
        let all: [Int] = [1, 3, 5, 8, 9]
        let belowAll = treap.split(at: 0)
        #expect(belowAll.lower.isEmpty)
        #expect(Array(belowAll.upper) == all)
        let aboveAll = treap.split(at: 10)
        #expect(Array(aboveAll.lower) == all)
        #expect(aboveAll.upper.isEmpty)
        let ofEmpty = Treap<Int>().split(at: 1)
        #expect(ofEmpty.lower.isEmpty)
        #expect(ofEmpty.upper.isEmpty)
    }

    @Test("split(at:) leaves the treap it was called on unchanged", .tags(.copyOnWrite))
    func splitLeavesOriginal() {
        let treap = Treap(1 ... 20)
        let parts = treap.split(at: 15)
        #expect(Array(treap) == Array(1 ... 20))
        #expect(Array(parts.lower) == Array(1 ... 14))
        #expect(Array(parts.upper) == Array(15 ... 20))
    }

    @Test("Both parts of a split are full treaps: they insert, remove and index by rank")
    func splitPartsWork() {
        var parts = Treap(1 ... 30).split(at: 11)
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

    @Test("join(_:) adds a treap whose elements lie all above or all below")
    func join() throws {
        var low: Treap = [1, 2, 3]
        try low.join([7, 8])
        let joinedAbove: [Int] = [1, 2, 3, 7, 8]
        #expect(Array(low) == joinedAbove)
        var high: Treap = [7, 8]
        try high.join([1, 2, 3])
        #expect(Array(high) == joinedAbove)
        var empty = Treap<Int>()
        try empty.join([4, 5])
        let joinedIntoEmpty: [Int] = [4, 5]
        #expect(Array(empty) == joinedIntoEmpty)
        var unchanged: Treap = [4, 5]
        try unchanged.join([])
        #expect(Array(unchanged) == joinedIntoEmpty)
    }

    @Test("join(_:) throws OverlappingKeys when the elements interleave or meet, and changes nothing")
    func joinOverlapping() {
        var treap: Treap = [1, 5, 9]
        let interleaved: Treap = [3, 4]
        #expect(throws: OverlappingKeys()) { try treap.join(interleaved) }
        let sharing: Treap = [9, 10]
        #expect(throws: OverlappingKeys()) { try treap.join(sharing) }
        let unchanged: [Int] = [1, 5, 9]
        #expect(Array(treap) == unchanged)
    }

    @Test("Splitting and joining the parts gives back the treap, at every split point", .tags(.exhaustive))
    func splitJoinRoundTrip() throws {
        var rng = SeededRandomNumberGenerator(seed: 3)
        let treap = Treap((0 ..< 40).map { $0 * 2 }, using: &rng)
        for point in -1 ... 80 {
            let parts = treap.split(at: point)
            #expect(parts.lower.allSatisfy { $0 < point }, "split at \(point)")
            #expect(parts.upper.allSatisfy { $0 >= point }, "split at \(point)")
            var rejoined = parts.lower
            try rejoined.join(parts.upper)
            #expect(rejoined == treap, "split at \(point)")
            var reversed = parts.upper
            try reversed.join(parts.lower)
            #expect(reversed == treap, "split at \(point)")
        }
    }

    @Test("Mutating a copy leaves the original alone", .tags(.copyOnWrite))
    func copyOnWrite() throws {
        let original: Treap = [1, 2, 3]
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
        var treap = Treap(0 ..< 100)
        let before = treap._core.nodes.withUnsafeBufferPointer { $0.baseAddress }
        treap.remove(50)
        treap.insert(50)
        treap.remove(at: 3)
        let after = treap._core.nodes.withUnsafeBufferPointer { $0.baseAddress }
        #expect(before == after)
    }

    @Test("Treaps are equal when their elements are, whatever their shapes", .tags(.conformance))
    func equality() throws {
        var inserted = Treap<Int>()
        for element in 1 ... 7 {
            inserted.insert(element)
        }
        let built = Treap(1 ... 7)
        #expect(inserted == built)
        #expect(inserted.hashValue == built.hashValue)
        #expect(built != [1, 2, 3])
        #expect(built != Treap(2 ... 8))
        let insertedShape = try #require(BinaryTree(inserted))
        let builtShape = try #require(BinaryTree(built))
        #expect(insertedShape.inorder == builtShape.inorder)
    }

    @Test("Codable round-trips the elements as a sorted array", .tags(.conformance))
    func codable() throws {
        let treap: Treap = [3, 1, 2]
        let data = try JSONEncoder().encode(treap)
        let asArray = try JSONDecoder().decode([Int].self, from: data)
        let sorted: [Int] = [1, 2, 3]
        #expect(asArray == sorted)
        let decoded = try JSONDecoder().decode(Treap<Int>.self, from: data)
        #expect(decoded == treap)
        let unsorted = Data("[5, 1, 5, 3]".utf8)
        let fromUnsorted = try JSONDecoder().decode(Treap<Int>.self, from: unsorted)
        let expected: [Int] = [1, 3, 5]
        #expect(Array(fromUnsorted) == expected)
    }

    @Test("The description is the elements written as an array", .tags(.conformance))
    func description() {
        let treap: Treap = ["b", "a"]
        let expected = #"["a", "b"]"#
        #expect(treap.description == expected)
    }

    @Test("The shape's in-order traversal is the elements, and its height one less", .tags(.fixture))
    func binaryTreeShape() throws {
        var treap = Treap<Int>()
        for element in [8, 3, 10, 1, 6, 14, 4, 7, 13] {
            treap.insert(element)
        }
        let shape = try #require(BinaryTree(treap))
        #expect(shape.inorder == Array(treap))
        #expect(shape.vertexCount == treap.count)
        #expect(shape.height == treap.height - 1)
    }

    @Test("The same seed gives the same shape, through inserts, removes, splits and joins", .tags(.randomized))
    func seededRunsReproduce() throws {
        func run() throws -> [Int] {
            var rng = SeededRandomNumberGenerator(seed: 4)
            var treap = Treap((0 ..< 50).map { $0 * 3 }, using: &rng)
            for element in 0 ..< 40 {
                treap.insert(element * 5)
            }
            treap.remove(30)
            var parts = treap.split(at: 100)
            parts.upper.insert(400)
            try parts.lower.join(parts.upper)
            let shape = try #require(BinaryTree(parts.lower))
            return Array(shape.preorder)
        }
        #expect(try run() == run())
    }

    @Test("BST order, heap order and subtree sizes hold after every seeded operation", .tags(.randomized))
    func invariantsUnderRandomOperations() throws {
        var rng = SeededRandomNumberGenerator(seed: 5)
        var treap = Treap<Int>(using: &rng)
        var reference = Set<Int>()
        for step in 0 ..< 3_000 {
            let element = Int.random(in: 0 ..< 400, using: &rng)
            switch Int.random(in: 0 ..< 20, using: &rng) {
            case 0:
                // Split and join back, in either order.
                let parts = treap.split(at: element)
                if Bool.random(using: &rng) {
                    treap = parts.lower
                    try treap.join(parts.upper)
                } else {
                    treap = parts.upper
                    try treap.join(parts.lower)
                }
            case 1 ... 10 where step >= 300:
                #expect(treap.remove(element) == reference.remove(element))
            default:
                #expect(treap.insert(element).inserted == reference.insert(element).inserted)
            }
            // Read the priorities from the storage: no child's exceeds its parent's.
            let nodes = treap._core.nodes
            let root = treap._core.root
            var stack: [(slot: Int32, low: Int?, high: Int?)] = root < 0 ? [] : [(root, nil, nil)]
            var visited = 0
            var orderViolations = 0
            var heapViolations = 0
            var sizeMismatches = 0
            while let (x, low, high) = stack.popLast() {
                visited += 1
                let node = nodes[Int(x)]
                if let low, !(low < node.key) { orderViolations += 1 }
                if let high, !(node.key < high) { orderViolations += 1 }
                let leftSize = node.left < 0 ? 0 : Int(nodes[Int(node.left)].size)
                let rightSize = node.right < 0 ? 0 : Int(nodes[Int(node.right)].size)
                if Int(node.size) != leftSize + rightSize + 1 { sizeMismatches += 1 }
                if node.left >= 0 {
                    if nodes[Int(node.left)].balance > node.balance { heapViolations += 1 }
                    stack.append((node.left, low, node.key))
                }
                if node.right >= 0 {
                    if nodes[Int(node.right)].balance > node.balance { heapViolations += 1 }
                    stack.append((node.right, node.key, high))
                }
            }
            #expect(visited == treap.count, "unreachable vertices at step \(step)")
            #expect(orderViolations == 0, "a key out of search-tree order at step \(step)")
            #expect(heapViolations == 0, "a child's priority above its parent's at step \(step)")
            #expect(sizeMismatches == 0, "a subtree size is wrong at step \(step)")
            if step % 200 == 0 {
                #expect(Array(treap) == reference.sorted())
            }
        }
        #expect(Array(treap) == reference.sorted())
    }

    @Test("A treap built from a sequence has heap-ordered priorities and right sizes for every count", .tags(.exhaustive))
    func builtTreapsAreTreaps() {
        var rng = SeededRandomNumberGenerator(seed: 6)
        for count in 0 ... 70 {
            let treap = Treap(0 ..< count, using: &rng)
            let nodes = treap._core.nodes
            let root = treap._core.root
            var stack: [Int32] = root < 0 ? [] : [root]
            var visited = 0
            var heapViolations = 0
            var sizeMismatches = 0
            while let x = stack.popLast() {
                visited += 1
                let node = nodes[Int(x)]
                let leftSize = node.left < 0 ? 0 : Int(nodes[Int(node.left)].size)
                let rightSize = node.right < 0 ? 0 : Int(nodes[Int(node.right)].size)
                if Int(node.size) != leftSize + rightSize + 1 { sizeMismatches += 1 }
                for child in [node.left, node.right] where child >= 0 {
                    if nodes[Int(child)].balance > node.balance { heapViolations += 1 }
                    stack.append(child)
                }
            }
            #expect(visited == count, "count \(count)")
            #expect(heapViolations == 0, "count \(count)")
            #expect(sizeMismatches == 0, "count \(count)")
            #expect(Array(treap) == Array(0 ..< count), "count \(count)")
            for rank in 0 ..< count {
                #expect(treap[rank] == rank, "count \(count)")
            }
        }
    }

    @Test("The checked spellings throw IndexOutOfRange outside the indices")
    func checkedThrows() {
        var treap: Treap = [1, 2, 3]
        #expect(throws: IndexOutOfRange()) { try treap[checked: 3] }
        #expect(throws: IndexOutOfRange()) { try treap[checked: -1] }
        #expect(throws: IndexOutOfRange()) { try treap.remove(checkedAt: 3) }
        #expect(throws: IndexOutOfRange()) { try treap.remove(checkedAt: -1) }
        let unchanged: [Int] = [1, 2, 3]
        #expect(Array(treap) == unchanged)
        #expect(throws: IndexOutOfRange()) { try Treap<Int>()[checked: 0] }
    }

    @Test("The checked spellings agree with the plain ones inside the indices")
    func checkedAgrees() throws {
        var treap: Treap = [1, 2, 3]
        #expect(try treap[checked: 1] == treap[1])
        let removed: Int = 2
        #expect(try treap.remove(checkedAt: 1) == removed)
        let rest: [Int] = [1, 3]
        #expect(Array(treap) == rest)
    }

}
