// Each test is self-contained: it builds its own lists and states its own expectations, so it can
// be copied into another file and still run. Nothing here is shared but the imports. A skip
// list's towers depend on its random heights, so the tests check its elements and its invariants,
// not particular towers; the invariant tests read the levels from `package` storage.

import Foundation
import GrafluentCollectionsTestSupport
import GraphProtocols
import SkipLists
import Testing

@Suite("SkipList: hand-worked cases")
struct SkipListTests {
    @Test("Inserting keeps the elements in ascending order and reports what was inserted")
    func insert() {
        var list = SkipList<Int>()
        for element in [5, 2, 8, 1, 9, 3] {
            #expect(list.insert(element).inserted)
        }
        let expected: [Int] = [1, 2, 3, 5, 8, 9]
        #expect(Array(list) == expected)
        #expect(list.count == 6)
    }

    @Test("Removing every element, in any order, leaves the rest in order each time")
    func remove() {
        var list = SkipList(1 ... 7)
        var rest = Array(1 ... 7)
        for element in [7, 1, 4, 2, 6, 3, 5] {
            let removed: Int? = element
            #expect(list.remove(element) == removed)
            rest.removeAll { $0 == element }
            #expect(Array(list) == rest)
            #expect(!list.contains(element))
        }
        #expect(list.isEmpty)
        #expect(list.level == 1)
    }

    @Test("Removing an absent element changes nothing and returns nil")
    func removeAbsent() {
        var list: SkipList = [1, 2, 3]
        #expect(list.remove(4) == nil)
        #expect(list.remove(0) == nil)
        let expected: [Int] = [1, 2, 3]
        #expect(Array(list) == expected)
        var empty = SkipList<Int>()
        #expect(empty.remove(1) == nil)
    }

    @Test("insert(_:) reports an equal member already present, and update(with:) replaces it")
    func duplicates() {
        var list: SkipList = [1, 2, 3]
        let again = list.insert(2)
        #expect(!again.inserted)
        #expect(again.memberAfterInsert == 2)
        #expect(list.count == 3)
        let fresh = list.insert(4)
        #expect(fresh.inserted)
        #expect(fresh.memberAfterInsert == 4)
        let replaced: Int? = 2
        #expect(list.update(with: 2) == replaced)
        #expect(list.update(with: 9) == nil)
        let expected: [Int] = [1, 2, 3, 4, 9]
        #expect(Array(list) == expected)
    }

    @Test("Of equal elements, init keeps the first, update(with:) the new one, insert the old one")
    func equalElementsKept() {
        struct Tagged: Comparable {
            var key: Int
            var tag: String
            static func < (lhs: Tagged, rhs: Tagged) -> Bool { lhs.key < rhs.key }
            static func == (lhs: Tagged, rhs: Tagged) -> Bool { lhs.key == rhs.key }
        }
        var list = SkipList([Tagged(key: 2, tag: "first"), Tagged(key: 1, tag: "a"), Tagged(key: 2, tag: "second")])
        let firstKept: [String] = ["a", "first"]
        let updated: [String] = ["a", "updated"]
        #expect(list.map(\.tag) == firstKept)
        list.insert(Tagged(key: 2, tag: "inserted"))
        #expect(list.map(\.tag) == firstKept)
        list.update(with: Tagged(key: 2, tag: "updated"))
        #expect(list.map(\.tag) == updated)
    }

    @Test("A literal or sequence with duplicates holds each element once, in ascending order")
    func duplicatesInInput() {
        let list: SkipList = [3, 1, 3, 2, 1]
        let expected: [Int] = [1, 2, 3]
        #expect(Array(list) == expected)
        #expect(list.count == 3)
    }

    @Test("Indices are ranks: the subscript reads the k-th smallest element")
    func ranks() {
        var list = SkipList<Int>()
        for element in [40, 10, 30, 20, 50] {
            list.insert(element)
        }
        let expected: [Int] = [10, 20, 30, 40, 50]
        for (rank, element) in expected.enumerated() {
            #expect(list[rank] == element)
        }
        #expect(list.firstIndex(of: 30) == 2)
        #expect(list.firstIndex(of: 35) == nil)
        #expect(list.lastIndex(of: 50) == 4)
        #expect(list.reversed() == expected.reversed())
    }

    @Test("lowerBound and upperBound bracket an element, present or not")
    func bounds() {
        let list: SkipList = [10, 20, 30]
        let zero = 0, one = 1, two = 2, three = 3
        #expect(list.lowerBound(20) == one)
        #expect(list.upperBound(20) == two)
        #expect(list.lowerBound(25) == two)
        #expect(list.upperBound(25) == two)
        #expect(list.lowerBound(5) == zero)
        #expect(list.upperBound(30) == three)
        #expect(list.lowerBound(35) == three)
    }

    @Test("elements(in:) is the elements in a half-open or closed range of values")
    func rangeQueries() {
        let list = SkipList(stride(from: 0, to: 100, by: 10))
        let halfOpen: [Int] = [20, 30, 40]
        let closed: [Int] = [20, 30, 40, 50]
        let empty: [Int] = []
        #expect(Array(list.elements(in: 15 ..< 50)) == halfOpen)
        #expect(Array(list.elements(in: 20 ... 50)) == closed)
        #expect(Array(list.elements(in: 41 ..< 49)) == empty)
        #expect(Array(list.elements(in: 200 ... 300)) == empty)
    }

    @Test("min and max are the ends, and nil when empty")
    func extremes() {
        let list: SkipList = [5, 1, 9, 3]
        let one: Int? = 1
        let nine: Int? = 9
        #expect(list.min() == one)
        #expect(list.max() == nine)
        #expect(SkipList<Int>().min() == nil)
        #expect(SkipList<Int>().max() == nil)
    }

    @Test("An empty list has no elements, level 1 and bounds at 0")
    func empty() {
        let list = SkipList<Int>()
        #expect(list.isEmpty)
        #expect(list.count == 0)
        #expect(list.level == 1)
        #expect(Array(list).isEmpty)
        #expect(list.lowerBound(1) == 0)
        #expect(list.upperBound(1) == 0)
        #expect(!list.contains(1))
        #expect(list.layersView.vertices.isEmpty)
        #expect(list.layersView.edges.isEmpty)
    }

    @Test("A one-element list holds it at rank 0, with no edge along the bottom level")
    func oneElement() {
        var list: SkipList = [7]
        #expect(list.count == 1)
        #expect(list[0] == 7)
        #expect(list.contains(7))
        let layers = list.layersView
        let bottom = SkipList<Int>.LayersView.Vertex(level: 0, element: 7)
        #expect(layers.contains(bottom))
        #expect(layers.successors(of: bottom).isEmpty)
        #expect(layers.vertexCount == list.level)
        list.remove(7)
        #expect(list.isEmpty)
    }

    @Test("remove(at:) removes by rank")
    func removeAtRank() {
        var list = SkipList(stride(from: 0, to: 50, by: 5))
        let removed: Int = 15
        #expect(list.remove(at: 3) == removed)
        let first: Int = 0
        #expect(list.remove(at: 0) == first)
        let last: Int = 45
        #expect(list.remove(at: list.count - 1) == last)
        let expected: [Int] = [5, 10, 20, 25, 30, 35, 40]
        #expect(Array(list) == expected)
    }

    @Test("Set algebra agrees with Set on two overlapping lists")
    func setAlgebra() {
        let a: SkipList = [1, 2, 3, 4, 5]
        let b: SkipList = [4, 5, 6, 7]
        let setA: Set = [1, 2, 3, 4, 5]
        let setB: Set = [4, 5, 6, 7]
        #expect(Array(a.union(b)) == setA.union(setB).sorted())
        #expect(Array(a.intersection(b)) == setA.intersection(setB).sorted())
        #expect(Array(a.symmetricDifference(b)) == setA.symmetricDifference(setB).sorted())
        #expect(Array(a.subtracting(b)) == setA.subtracting(setB).sorted())
        var c = a
        c.formUnion(b)
        #expect(Array(c) == setA.union(setB).sorted())
        c = a
        c.formIntersection(b)
        #expect(Array(c) == setA.intersection(setB).sorted())
        c = a
        c.formSymmetricDifference(b)
        #expect(Array(c) == setA.symmetricDifference(setB).sorted())
        c = a
        c.subtract(b)
        #expect(Array(c) == setA.subtracting(setB).sorted())
        #expect(a.isSubset(of: a.union(b)))
        #expect(a.isDisjoint(with: [8, 9]))
    }

    @Test("Mutating a copy leaves the original alone", .tags(.copyOnWrite))
    func copyOnWrite() {
        let original: SkipList = [1, 2, 3]
        var copy = original
        copy.insert(4)
        copy.remove(1)
        copy.remove(at: 0)
        let originalElements: [Int] = [1, 2, 3]
        let copyElements: [Int] = [3, 4]
        #expect(Array(original) == originalElements)
        #expect(Array(copy) == copyElements)
    }

    @Test("A unique owner mutates its storage in place", .tags(.copyOnWrite))
    func uniqueMutatesInPlace() {
        var list = SkipList(0 ..< 100)
        let before = list._core.elements.withUnsafeBufferPointer { $0.baseAddress }
        list.remove(50)
        list.insert(50)
        list.remove(at: 3)
        let after = list._core.elements.withUnsafeBufferPointer { $0.baseAddress }
        #expect(before == after)
    }

    @Test("Skip lists are equal when their elements are, whatever their towers", .tags(.conformance))
    func equality() {
        var inserted = SkipList<Int>()
        for element in 1 ... 7 {
            inserted.insert(element)
        }
        let built = SkipList(1 ... 7)
        #expect(inserted == built)
        #expect(inserted.hashValue == built.hashValue)
        #expect(built != [1, 2, 3])
        #expect(built != SkipList(2 ... 8))
    }

    @Test("Codable round-trips the elements as a sorted array", .tags(.conformance))
    func codable() throws {
        let list: SkipList = [3, 1, 2]
        let data = try JSONEncoder().encode(list)
        let asArray = try JSONDecoder().decode([Int].self, from: data)
        let sorted: [Int] = [1, 2, 3]
        #expect(asArray == sorted)
        let decoded = try JSONDecoder().decode(SkipList<Int>.self, from: data)
        #expect(decoded == list)
        let unsorted = Data("[5, 1, 5, 3]".utf8)
        let fromUnsorted = try JSONDecoder().decode(SkipList<Int>.self, from: unsorted)
        let expected: [Int] = [1, 3, 5]
        #expect(Array(fromUnsorted) == expected)
    }

    @Test("The description is the elements written as an array", .tags(.conformance))
    func description() {
        let list: SkipList = ["b", "a"]
        let expected = #"["a", "b"]"#
        #expect(list.description == expected)
    }

    @Test("The layers view has a vertex per tower level, edges along each level and down each tower", .tags(.fixture))
    func layersView() {
        var rng = SeededRandomNumberGenerator(seed: 2)
        let list = SkipList(0 ..< 200, using: &rng)
        let layers = list.layersView
        typealias Vertex = SkipList<Int>.LayersView.Vertex
        let vertices = Array(layers.vertices)
        #expect(vertices.count == layers.vertexCount)
        #expect(Set(vertices).count == vertices.count)
        #expect(vertices.filter { $0.level == 0 }.map(\.element) == Array(0 ..< 200))
        #expect(vertices.allSatisfy { layers.contains($0) })
        #expect(!layers.contains(Vertex(level: 0, element: 200)))
        #expect(!layers.contains(Vertex(level: -1, element: 0)))
        #expect(!layers.contains(Vertex(level: list.level, element: 0)))
        // Each level, read along its edges from its smallest element, is ascending and a
        // subsequence of the level below.
        var below = Array(0 ..< 200)
        for level in 0 ..< list.level {
            let onLevel = vertices.filter { $0.level == level }.map(\.element)
            #expect(onLevel == onLevel.sorted())
            #expect(Set(onLevel).isSubset(of: below))
            var walked: [Int] = []
            var current = onLevel.first.map { Vertex(level: level, element: $0) }
            while let vertex = current {
                walked.append(vertex.element)
                current = layers.successors(of: vertex).first { $0.level == level }
            }
            #expect(walked == onLevel, "level \(level)")
            below = onLevel
        }
        // Every edge is listed once, from its source, along a level or one level down.
        let edges = Array(layers.edges)
        #expect(edges.count == layers.edgeCount)
        var fromOutEdges: [DirectedEdge<Vertex>] = []
        for vertex in vertices {
            for position in layers.outEdges(of: vertex) {
                fromOutEdges.append(layers.edges[position])
            }
        }
        #expect(fromOutEdges == edges)
        let wellFormed = edges.allSatisfy { edge in
            (edge.target.level == edge.source.level && edge.source.element < edge.target.element)
                || (edge.target.level == edge.source.level - 1 && edge.source.element == edge.target.element)
        }
        #expect(wellFormed)
        let levels = Set(vertices.map(\.level))
        #expect(edges.count == vertices.count - levels.count + vertices.count - list.count)
    }

    @Test("The same seed gives the same towers, through inserts and removes", .tags(.randomized))
    func seededRunsReproduce() {
        func run() -> [Int] {
            var rng = SeededRandomNumberGenerator(seed: 4)
            var list = SkipList((0 ..< 50).map { $0 * 3 }, using: &rng)
            for element in 0 ..< 40 {
                list.insert(element * 5)
            }
            list.remove(30)
            list.remove(at: 7)
            return list.layersView.vertices.map { $0.level * 1_000 + $0.element }
        }
        #expect(run() == run())
    }

    @Test("Order, nesting, spans and reachability hold after every seeded operation", .tags(.randomized))
    func invariantsUnderRandomOperations() {
        var rng = SeededRandomNumberGenerator(seed: 5)
        var list = SkipList<Int>(using: &rng)
        var reference = Set<Int>()
        for step in 0 ..< 3_000 {
            let element = Int.random(in: 0 ..< 400, using: &rng)
            switch Int.random(in: 0 ..< 20, using: &rng) {
            case 0 where !list.isEmpty:
                let rank = Int.random(in: 0 ..< list.count, using: &rng)
                let removed = list.remove(at: rank)
                #expect(reference.remove(removed) != nil)
            case 1 ... 10 where step >= 300:
                #expect(list.remove(element) == reference.remove(element))
            default:
                #expect(list.insert(element).inserted == reference.insert(element).inserted)
            }
            // Walk every level from the head, reading the storage.
            let core = list._core
            var orderViolations = 0
            var heightViolations = 0
            var spanMismatches = 0
            var nestingViolations = 0
            var towerMismatches = 0
            var rankOfSlot = [Int32: Int]()
            var below: Set<Int32> = []
            for level in 0 ..< core.level {
                var tower = 0
                var rank = 0
                var previous: Int?
                var onLevel: Set<Int32> = []
                while true {
                    let link = core.links[tower + level]
                    guard link.next >= 0 else {
                        if Int(link.span) != core.count - rank { spanMismatches += 1 }
                        break
                    }
                    let slot = link.next
                    let element = core.elements[Int(slot)]
                    if link.tower != core.towers[Int(slot)] { towerMismatches += 1 }
                    if let previous, !(previous < element) { orderViolations += 1 }
                    if Int(core.heights[Int(slot)]) <= level { heightViolations += 1 }
                    if level == 0 {
                        rankOfSlot[slot] = rank + 1
                    } else if !below.contains(slot) {
                        nestingViolations += 1
                    }
                    let targetRank = rankOfSlot[slot] ?? -1
                    if Int(link.span) != targetRank - rank { spanMismatches += 1 }
                    onLevel.insert(slot)
                    rank = targetRank
                    previous = element
                    tower = Int(core.towers[Int(slot)])
                }
                below = onLevel
            }
            let tallest = core.heights.map(Int.init).max() ?? 1
            #expect(rankOfSlot.count == list.count, "unreachable elements at step \(step)")
            #expect(orderViolations == 0, "a level out of order at step \(step)")
            #expect(heightViolations == 0, "an element above its tower at step \(step)")
            #expect(nestingViolations == 0, "a level not a subsequence of the one below at step \(step)")
            #expect(spanMismatches == 0, "a span is wrong at step \(step)")
            #expect(towerMismatches == 0, "a link names the wrong tower at step \(step)")
            #expect(core.level == Swift.max(1, tallest), "the level is not the tallest tower at step \(step)")
            if step % 200 == 0 {
                #expect(Array(list) == reference.sorted())
            }
        }
        #expect(Array(list) == reference.sorted())
    }

    @Test("A list built from a sequence reads back by rank and holds its levels for every count", .tags(.exhaustive))
    func builtListsAreSkipLists() {
        var rng = SeededRandomNumberGenerator(seed: 6)
        for count in 0 ... 70 {
            let list = SkipList(0 ..< count, using: &rng)
            #expect(Array(list) == Array(0 ..< count), "count \(count)")
            for rank in 0 ..< count {
                #expect(list[rank] == rank, "count \(count)")
                #expect(list.lowerBound(rank) == rank, "count \(count)")
            }
            var grown = SkipList<Int>(using: &rng)
            for element in 0 ..< count {
                grown.insert(element)
            }
            #expect(grown == list, "count \(count)")
            let vertices = Array(list.layersView.vertices)
            #expect(vertices.filter { $0.level == 0 }.count == count, "count \(count)")
        }
    }

    @Test("The checked spellings throw IndexOutOfRange outside the indices")
    func checkedThrows() {
        var list: SkipList = [1, 2, 3]
        #expect(throws: IndexOutOfRange()) { try list[checked: 3] }
        #expect(throws: IndexOutOfRange()) { try list[checked: -1] }
        #expect(throws: IndexOutOfRange()) { try list.remove(checkedAt: 3) }
        #expect(throws: IndexOutOfRange()) { try list.remove(checkedAt: -1) }
        let unchanged: [Int] = [1, 2, 3]
        #expect(Array(list) == unchanged)
        #expect(throws: IndexOutOfRange()) { try SkipList<Int>()[checked: 0] }
    }

    @Test("The checked spellings agree with the plain ones inside the indices")
    func checkedAgrees() throws {
        var list: SkipList = [1, 2, 3]
        #expect(try list[checked: 1] == list[1])
        let removed: Int = 2
        #expect(try list.remove(checkedAt: 1) == removed)
        let rest: [Int] = [1, 3]
        #expect(Array(list) == rest)
    }

    @Test("The plain spellings trap outside the indices", .tags(.precondition))
    func plainTraps() async {
        await #expect(processExitsWith: .failure) {
            let list: SkipList = [1, 2, 3]
            _ = list[3]
        }
        await #expect(processExitsWith: .failure) {
            let list: SkipList = [1, 2, 3]
            _ = list[-1]
        }
        await #expect(processExitsWith: .failure) {
            var list: SkipList = [1, 2, 3]
            list.remove(at: 3)
        }
        await #expect(processExitsWith: .failure) {
            var list = SkipList<Int>()
            list.remove(at: 0)
        }
    }
}
