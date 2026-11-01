// Tests for IntervalTree. Each test builds its own tree and checks it against a hand-worked
// answer or a linear filter over an array of entries, so it can be copied into another file and
// still run. Nothing here is shared but the imports.

import GrafluentCollectionsTestSupport
import PropertyBased
import RangeTrees
import Testing
import Trees

@Suite("IntervalTree: hand-worked cases")
struct IntervalTreeTests {
    @Test("A day's schedule: what is on at 11, what overlaps the morning, and what fits before noon")
    func schedule() {
        var meetings = IntervalTree<Int, String>()
        meetings.insert(9 ..< 10, value: "stand-up")
        meetings.insert(10 ..< 12, value: "design review")
        meetings.insert(11 ..< 13, value: "lunch")
        meetings.insert(14 ..< 15, value: "one-on-one")
        meetings.insert(8 ..< 17, value: "office hours")
        let atEleven = ["office hours", "design review", "lunch"]
        let morning = ["office hours", "stand-up", "design review"]
        let beforeNoon = ["stand-up", "design review"]
        #expect(meetings.containing(11).map(\.value) == atEleven)
        #expect(meetings.overlapping(9 ..< 11).map(\.value) == morning)
        #expect(meetings.contained(in: 9 ..< 12).map(\.value) == beforeNoon)
        let five = 5
        #expect(meetings.count == five)
        let order = ["office hours", "stand-up", "design review", "lunch", "one-on-one"]
        #expect(meetings.map(\.value) == order)
        let third = "design review"
        #expect(meetings[2].value == third)
    }

    @Test("Half-open intervals that touch do not overlap, and an upper bound is not contained")
    func touchingIntervals() {
        let tree = IntervalTree<Int, Int>([.init(range: 0 ..< 5, value: 0), .init(range: 5 ..< 10, value: 1)])
        let first = [0], second = [1], none: [Int] = []
        #expect(tree.containing(5).map(\.value) == second)
        #expect(tree.containing(4).map(\.value) == first)
        #expect(tree.containing(10).map(\.value) == none)
        #expect(tree.overlapping(5 ..< 6).map(\.value) == second)
        #expect(tree.overlapping(0 ..< 5).map(\.value) == first)
        #expect(tree.overlapping(3 ..< 3).map(\.value) == none)
        let both = [0, 1]
        #expect(tree.contained(in: 0 ..< 10).map(\.value) == both)
        #expect(tree.contained(in: 1 ..< 10).map(\.value) == second)
    }

    @Test("Equal intervals keep their insertion order, and remove takes the earliest")
    func duplicates() {
        var tree = IntervalTree<Double, String>()
        tree.insert(1 ..< 2, value: "a")
        tree.insert(0 ..< 3, value: "b")
        tree.insert(1 ..< 2, value: "c")
        tree.insert(1 ..< 2, value: "d")
        let all = ["b", "a", "c", "d"]
        #expect(tree.containing(1.5).map(\.value) == all)
        let removed: String? = "a", missing: String? = nil
        #expect(tree.remove(1 ..< 2) == removed)
        let rest = ["b", "c", "d"]
        #expect(tree.map(\.value) == rest)
        #expect(tree.remove(1 ..< 3) == missing)
        #expect(tree.remove(5 ..< 6) == missing)
    }

    @Test("Removing the long interval that set every largest upper bound narrows the searches")
    func removalKeepsAugmentation() {
        var tree = IntervalTree<Int, Int>()
        for k in 0 ..< 50 {
            tree.insert(k ..< k + 1, value: k)
        }
        tree.insert(0 ..< 1_000, value: -1)
        let both = [-1, 30]
        #expect(tree.containing(30).map(\.value) == both)
        let late = [-1]
        #expect(tree.containing(500).map(\.value) == late)
        let removed: Int? = -1
        #expect(tree.remove(0 ..< 1_000) == removed)
        let nothing: [Int] = []
        #expect(tree.containing(500).map(\.value) == nothing)
        let one = [30]
        #expect(tree.containing(30).map(\.value) == one)
        for k in stride(from: 0, to: 50, by: 2) {
            tree.remove(k ..< k + 1)
        }
        let odd = [31, 33]
        #expect(tree.overlapping(30 ..< 34).map(\.value) == odd)
    }

    @Test("An empty tree finds nothing, and its shape is nil")
    func emptyTree() {
        let tree = IntervalTree<Int, Int>()
        #expect(tree.isEmpty)
        #expect(tree.containing(0).map(\.value).isEmpty)
        #expect(tree.overlapping(0 ..< 10).map(\.value).isEmpty)
        #expect(BinaryTree(tree) == nil)
        let one = IntervalTree<Int, Int>([.init(range: 0 ..< 1, value: 7)])
        let seven = [7]
        #expect(one.containing(0).map(\.value) == seven)
    }

    @Test("The shape has the tree's in-order positions as vertices and is height-balanced")
    func binaryTreeShape() throws {
        var tree = IntervalTree<Int, Int>()
        for k in 0 ..< 100 {
            tree.insert(k ..< k + 3, value: k)
        }
        let shape = try #require(BinaryTree(tree))
        let hundred = 100
        #expect(shape.vertexCount == hundred)
        #expect(shape.inorder == Array(0 ..< 100))
        #expect(shape.height <= 9)
    }

    @Test("The checked spellings throw EmptyRange and IndexOutOfRange and change nothing")
    func checkedSpellings() throws {
        var tree = IntervalTree<Int, Int>()
        #expect(throws: EmptyRange()) { try tree.insert(checked: 3 ..< 3, value: 0) }
        #expect(tree.isEmpty)
        try tree.insert(checked: 3 ..< 4, value: 1)
        let one = 1
        #expect(try tree[checked: 0].value == one)
        #expect(throws: IndexOutOfRange()) { try tree[checked: 1] }
        #expect(throws: EmptyRange()) {
            try IntervalTree<Int, Int>(checked: [.init(range: 0 ..< 1, value: 0), .init(range: 2 ..< 2, value: 1)])
        }
        let built = try IntervalTree<Int, Int>(checked: [.init(range: 0 ..< 1, value: 0)])
        #expect(built.count == one)
    }

    @Test("Empty intervals and positions out of range trap", .tags(.precondition))
    func plainTraps() async {
        await #expect(processExitsWith: .failure) {
            var tree = IntervalTree<Int, Int>()
            tree.insert(5 ..< 5, value: 0)
        }
        await #expect(processExitsWith: .failure) {
            _ = IntervalTree<Int, Int>([.init(range: 1 ..< 1, value: 0)])
        }
        await #expect(processExitsWith: .failure) {
            let tree = IntervalTree<Int, Int>([.init(range: 0 ..< 1, value: 0)])
            _ = tree[1]
        }
    }
}

@Suite("IntervalTree: properties")
struct IntervalTreePropertyTests {
    @Test("After random inserts and removes, every search matches a linear filter over the entries", .tags(.randomized))
    func matchesLinearFilter() async {
        let operations = Gen.int(in: 0 ... 1_000_000).array(of: 0 ... 80)
        let queries = Gen.int(in: 0 ... 1_000_000).array(of: 1 ... 20)
        await propertyCheck(count: 200, input: operations, queries) { operations, queries in
            var tree = IntervalTree<Int, Int>()
            var reference: [(range: Range<Int>, value: Int)] = []
            for (serial, operation) in operations.enumerated() {
                let lower = operation % 50, length = 1 + operation / 50 % 12
                let range = lower ..< lower + length
                if operation / 600 % 4 == 0 {
                    let expected = reference.firstIndex { $0.range == range }.map { reference.remove(at: $0).value }
                    #expect(tree.remove(range) == expected)
                } else {
                    tree.insert(range, value: serial)
                    reference.append((range, serial))
                }
            }
            func sorted(_ entries: [(range: Range<Int>, value: Int)]) -> [Int] {
                // Stable sort by interval; equal intervals stay in insertion order.
                entries.enumerated().sorted { a, b in
                    let (x, y) = (a.element.range, b.element.range)
                    if x.lowerBound != y.lowerBound { return x.lowerBound < y.lowerBound }
                    if x.upperBound != y.upperBound { return x.upperBound < y.upperBound }
                    return a.offset < b.offset
                }.map(\.element.value)
            }
            #expect(tree.map(\.value) == sorted(reference))
            #expect(tree.count == reference.count)
            for query in queries {
                let point = query % 65
                let lower = query / 65 % 65, upper = lower + query / 4_225 % 20
                let range = lower ..< upper
                #expect(tree.containing(point).map(\.value) == sorted(reference.filter { $0.range.contains(point) }))
                #expect(tree.overlapping(range).map(\.value) == sorted(reference.filter { $0.range.overlaps(range) }))
                #expect(tree.contained(in: range).map(\.value) == sorted(reference.filter { range.lowerBound <= $0.range.lowerBound && $0.range.upperBound <= range.upperBound }))
            }
        }
    }

    @Test("Building from entries gives the same tree as inserting them one at a time", .tags(.randomized))
    func buildMatchesInserts() {
        var rng = SeededRandomNumberGenerator(seed: 17)
        var entries: [IntervalTree<Int, Int>.Entry] = []
        for k in 0 ..< 300 {
            let lower = Int.random(in: 0 ..< 100, using: &rng)
            entries.append(.init(range: lower ..< lower + Int.random(in: 1 ... 10, using: &rng), value: k))
        }
        var inserted = IntervalTree<Int, Int>()
        for entry in entries {
            inserted.insert(entry.range, value: entry.value)
        }
        let built = IntervalTree(entries)
        #expect(built == inserted)
        for point in 0 ..< 110 {
            #expect(built.containing(point).map(\.value) == inserted.containing(point).map(\.value))
        }
    }
}
