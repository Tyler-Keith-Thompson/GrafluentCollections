// Tests for ZeroSuppressedDecisionDiagram. Each test builds its own families and checks them
// against a hand-worked answer or a Set<Set<Int>> reference, so it can be copied into another
// file and still run. Nothing here is shared but the imports.

import DecisionDiagrams
import GrafluentCollectionsTestSupport
import GraphProtocols
import PropertyBased
import Testing

@Suite("ZeroSuppressedDecisionDiagram: hand-worked cases")
struct ZeroSuppressedDecisionDiagramTests {
    @Test("{{0, 1}, {1, 2}, {2}} tests 0 at the root, and its sets without 0 share one test of 2")
    func handWorkedFamily() {
        var diagram = ZeroSuppressedDecisionDiagram(elementCount: 3)
        let f = diagram.family([[0, 1], [1, 2], [2]])
        let three: Double = 3
        #expect(diagram.count(of: f) == three)
        // The root tests 0. Its high child is {{1}}; its low child, {{1, 2}, {2}}, tests 1 with
        // {{2}} on both sides, which zero suppression allows.
        let graph = diagram.graphView
        let root = f.vertex
        let rootElement: Int? = 0
        #expect(graph.element(of: root) == rootElement)
        let rootChildren = graph.successors(of: root)
        let low = rootChildren[0], high = rootChildren[1]
        let one: Int? = 1, two: Int? = 2
        #expect(graph.element(of: low) == one)
        #expect(graph.element(of: high) == one)
        #expect(graph.successors(of: high) == [0, 1])
        let lowChildren = graph.successors(of: low)
        #expect(lowChildren[0] == lowChildren[1])
        #expect(graph.element(of: lowChildren[0]) == two)
        let six = 6
        #expect(diagram.vertexCount(of: f) == six)
    }

    @Test("The constants are the empty family and {∅}, with zero and one sets")
    func constants() {
        var diagram = ZeroSuppressedDecisionDiagram(elementCount: 4)
        let zero: Double = 0, one: Double = 1
        #expect(diagram.count(of: diagram.empty) == zero)
        #expect(diagram.count(of: diagram.unit) == one)
        #expect(diagram.family([[Int]]()) == diagram.empty)
        #expect(diagram.family([[Int]()]) == diagram.unit)
        #expect(diagram.contains([], in: diagram.unit))
        #expect(!diagram.contains([], in: diagram.empty))
        #expect(Array(diagram.setsView(of: diagram.empty)) == [])
        #expect(Array(diagram.setsView(of: diagram.unit)) == [[]])
        let two = 2
        #expect(diagram.tableVertexCount == two)
        let empty = ZeroSuppressedDecisionDiagram(elementCount: 0)
        #expect(empty.count(of: empty.unit) == one)
    }

    @Test("Zero suppression: one sparse set over ten elements is 3 vertices as a ZDD and 12 as a BDD")
    func zeroSuppressionKeepsSparseFamiliesSmall() {
        let n = 10
        var zdd = ZeroSuppressedDecisionDiagram(elementCount: n)
        let family = zdd.family([[0]])
        var bdd = BinaryDecisionDiagram(variableCount: n)
        var function = bdd.variable(0)
        for v in 1 ..< n {
            function = bdd.and(function, bdd.not(bdd.variable(v)))
        }
        let three = 3, twelve = 12
        #expect(zdd.vertexCount(of: family) == three)
        #expect(bdd.vertexCount(of: function) == twelve)
        let one: Double = 1
        #expect(zdd.count(of: family) == one)
        #expect(bdd.satisfyingAssignmentCount(of: function) == one)
    }

    @Test("Two constructions of one family give the same root, and building it again adds no vertex")
    func canonicity() {
        var diagram = ZeroSuppressedDecisionDiagram(elementCount: 4)
        let a = diagram.family([[0, 2], [1], [3, 1]])
        let size = diagram.tableVertexCount
        let again = diagram.family([[0, 2], [1], [3, 1]])
        #expect(again == a)
        #expect(diagram.tableVertexCount == size)
        let b = diagram.family([[1, 3], [2, 0, 2], [1], [1]])
        #expect(a == b)
        let joined = diagram.join(diagram.single(0), diagram.single(2))
        let pairs = diagram.family([[0, 2]])
        #expect(joined == pairs)
        let rebuilt = diagram.union(diagram.union(diagram.family([[1]]), diagram.family([[1, 3]])), pairs)
        #expect(rebuilt == a)
    }

    @Test("Union, intersection and difference of {{0}, {0, 1}} and {{0, 1}, {2}}")
    func setOperations() {
        var diagram = ZeroSuppressedDecisionDiagram(elementCount: 3)
        let f = diagram.family([[0], [0, 1]])
        let g = diagram.family([[0, 1], [2]])
        #expect(diagram.union(f, g) == diagram.family([[0], [0, 1], [2]]))
        #expect(diagram.intersection(f, g) == diagram.family([[0, 1]]))
        #expect(diagram.subtracting(g, from: f) == diagram.family([[0]]))
        #expect(diagram.subtracting(f, from: g) == diagram.family([[2]]))
        #expect(diagram.subtracting(f, from: f) == diagram.empty)
        #expect(diagram.union(f, diagram.empty) == f)
        #expect(diagram.intersection(f, diagram.unit) == diagram.empty)
    }

    @Test("Join takes every pairwise union and meet every pairwise intersection")
    func joinAndMeet() {
        var diagram = ZeroSuppressedDecisionDiagram(elementCount: 4)
        let f = diagram.family([[0], [1, 2]])
        let g = diagram.family([[], [2, 3]])
        #expect(diagram.join(f, g) == diagram.family([[0], [1, 2], [0, 2, 3], [1, 2, 3]]))
        #expect(diagram.meet(f, g) == diagram.family([[], [2]]))
        #expect(diagram.join(f, diagram.unit) == f)
        #expect(diagram.join(f, diagram.empty) == diagram.empty)
        #expect(diagram.meet(f, diagram.unit) == diagram.unit)
        #expect(diagram.meet(f, f) == diagram.family([[0], [1, 2], []]))
    }

    @Test("including and excluding keep the sets with and without an element")
    func includingAndExcluding() {
        var diagram = ZeroSuppressedDecisionDiagram(elementCount: 3)
        let f = diagram.family([[0, 1], [1, 2], [2], []])
        #expect(diagram.including(1, in: f) == diagram.family([[0, 1], [1, 2]]))
        #expect(diagram.excluding(1, in: f) == diagram.family([[2], []]))
        #expect(diagram.including(0, in: f) == diagram.family([[0, 1]]))
        #expect(diagram.excluding(2, in: f) == diagram.family([[0, 1], []]))
        #expect(diagram.including(0, in: diagram.unit) == diagram.empty)
    }

    @Test("Minimal and maximal sets of {{0}, {0, 1}, {1, 2}, {2}}")
    func minimalAndMaximal() {
        var diagram = ZeroSuppressedDecisionDiagram(elementCount: 3)
        let f = diagram.family([[0], [0, 1], [1, 2], [2]])
        #expect(diagram.minimalSets(of: f) == diagram.family([[0], [2]]))
        #expect(diagram.maximalSets(of: f) == diagram.family([[0, 1], [1, 2]]))
        let withEmpty = diagram.union(f, diagram.unit)
        #expect(diagram.minimalSets(of: withEmpty) == diagram.unit)
        #expect(diagram.maximalSets(of: withEmpty) == diagram.family([[0, 1], [1, 2]]))
    }

    @Test("The sets come ascending as binary numbers with element 0 most significant, each sorted")
    func setsViewOrder() {
        var diagram = ZeroSuppressedDecisionDiagram(elementCount: 2)
        let all = diagram.family([[0, 1], [1], [], [0]])
        let expected: [[Int]] = [[], [1], [0], [0, 1]]
        #expect(Array(diagram.setsView(of: all)) == expected)
        #expect(diagram.contains([1, 0], in: all))
        let partial = diagram.family([[1]])
        #expect(!diagram.contains([0], in: partial))
        #expect(!diagram.contains([], in: partial))
    }

    @Test("A path of n vertices has Fibonacci(n + 2) independent sets: 8 for 4, 2178309 for 30")
    func pathIndependentSets() {
        func independentSets(_ n: Int) -> Double {
            var diagram = ZeroSuppressedDecisionDiagram(elementCount: n)
            var sets = diagram.unit
            for v in 0 ..< n {
                sets = diagram.join(sets, diagram.union(diagram.unit, diagram.single(v)))
            }
            for v in 0 ..< n - 1 {
                let adjacent = diagram.including(v, in: diagram.including(v + 1, in: sets))
                sets = diagram.subtracting(adjacent, from: sets)
            }
            return diagram.count(of: sets)
        }
        let eight: Double = 8, fibonacci32: Double = 2_178_309
        #expect(independentSets(4) == eight)
        #expect(independentSets(30) == fibonacci32)
    }

    @Test("The power set of 70 elements counts 2⁷⁰ sets in 71 vertices, the empty family unreached")
    func largeCounts() {
        let n = 70
        var diagram = ZeroSuppressedDecisionDiagram(elementCount: n)
        var all = diagram.unit
        for v in 0 ..< n {
            all = diagram.join(all, diagram.union(diagram.unit, diagram.single(v)))
        }
        let expected = Double(sign: .plus, exponent: n, significand: 1)
        #expect(diagram.count(of: all) == expected)
        let vertices = 71
        #expect(diagram.vertexCount(of: all) == vertices)
    }

    @Test("The graph view has a low and a high edge per test, from the vertex to its children")
    func graphView() {
        var diagram = ZeroSuppressedDecisionDiagram(elementCount: 2)
        let f = diagram.family([[0], [1]])
        let graph = diagram.graphView
        #expect(graph.vertexCount == diagram.tableVertexCount)
        #expect(graph.edgeCount == 2 * (diagram.tableVertexCount - 2))
        for position in graph.edges.indices {
            let edge = graph.edges[position]
            let children = graph.successors(of: edge.source)
            #expect(edge.target == children[graph.isHighEdge(at: position) ? 1 : 0])
        }
        #expect(graph.successors(of: f.vertex).last == 1)
        #expect(graph.successors(of: 0).isEmpty)
        #expect(graph.element(of: 1) == nil)
    }

    @Test("The checked spelling throws IndexOutOfRange for an element out of range")
    func checkedThrows() throws {
        var diagram = ZeroSuppressedDecisionDiagram(elementCount: 2)
        let one = try diagram.single(checked: 1)
        #expect(one == diagram.single(1))
        #expect(throws: IndexOutOfRange()) { try diagram.single(checked: 2) }
        #expect(throws: IndexOutOfRange()) { try diagram.single(checked: -1) }
    }

    @Test("Elements out of range and families from a larger table trap", .tags(.precondition))
    func plainTraps() async {
        await #expect(processExitsWith: .failure) {
            var diagram = ZeroSuppressedDecisionDiagram(elementCount: 2)
            _ = diagram.single(2)
        }
        await #expect(processExitsWith: .failure) {
            var diagram = ZeroSuppressedDecisionDiagram(elementCount: 2)
            _ = diagram.family([[0, 3]])
        }
        await #expect(processExitsWith: .failure) {
            var diagram = ZeroSuppressedDecisionDiagram(elementCount: 2)
            _ = diagram.including(-1, in: diagram.unit)
        }
        await #expect(processExitsWith: .failure) {
            let diagram = ZeroSuppressedDecisionDiagram(elementCount: 2)
            _ = diagram.contains([5], in: diagram.unit)
        }
        await #expect(processExitsWith: .failure) {
            var big = ZeroSuppressedDecisionDiagram(elementCount: 4)
            let f = big.family([[2, 3], [1]])
            let small = ZeroSuppressedDecisionDiagram(elementCount: 4)
            _ = small.count(of: f)
        }
        await #expect(processExitsWith: .failure) {
            _ = ZeroSuppressedDecisionDiagram(elementCount: -1)
        }
    }
}

@Suite("ZeroSuppressedDecisionDiagram: properties")
struct ZeroSuppressedDecisionDiagramPropertyTests {
    @Test("Every family operation matches Set<Set<Int>> over universes of up to ten elements", .tags(.randomized))
    func familyOperationsMatchSets() async {
        // Each number is a set as a bit mask; its top bits pick the universe size and the element
        // the element-wise operations use.
        let masks = Gen.int(in: 0 ... 1_000_000).array(of: 1 ... 30)
        await propertyCheck(count: 200, input: masks) { masks in
            let n = 1 + masks[0] % 10
            let element = masks[0] / 10 % n
            func set(_ mask: Int) -> Set<Int> {
                Set((0 ..< n).filter { mask >> $0 & 1 == 1 })
            }
            let half = masks.count / 2
            let left = Set(masks[..<half].map(set))
            let right = Set(masks[half...].map(set))
            var diagram = ZeroSuppressedDecisionDiagram(elementCount: n)
            func build(_ family: Set<Set<Int>>) -> ZeroSuppressedDecisionDiagram.Family {
                diagram.family(family.map { Array($0) })
            }
            let f = build(left), g = build(right)
            func read(_ family: ZeroSuppressedDecisionDiagram.Family) -> Set<Set<Int>> {
                Set(diagram.setsView(of: family).map { Set($0) })
            }
            #expect(read(f) == left)
            #expect(diagram.count(of: f) == Double(left.count))
            #expect(read(diagram.union(f, g)) == left.union(right))
            #expect(read(diagram.intersection(f, g)) == left.intersection(right))
            #expect(read(diagram.subtracting(g, from: f)) == left.subtracting(right))
            var joins = Set<Set<Int>>(), meets = Set<Set<Int>>()
            for a in left {
                for b in right {
                    joins.insert(a.union(b))
                    meets.insert(a.intersection(b))
                }
            }
            #expect(read(diagram.join(f, g)) == joins)
            #expect(read(diagram.meet(f, g)) == meets)
            #expect(read(diagram.including(element, in: f)) == left.filter { $0.contains(element) })
            #expect(read(diagram.excluding(element, in: f)) == left.filter { !$0.contains(element) })
            let minimal = left.filter { a in !left.contains { $0 != a && $0.isSubset(of: a) } }
            let maximal = left.filter { a in !left.contains { $0 != a && a.isSubset(of: $0) } }
            #expect(read(diagram.minimalSets(of: f)) == minimal)
            #expect(read(diagram.maximalSets(of: f)) == maximal)
            for mask in masks {
                #expect(diagram.contains(set(mask), in: f) == left.contains(set(mask)))
            }
            // Canonicity: the result of an operation is the root that building its sets gives.
            #expect(diagram.join(f, g) == build(joins))
            #expect(diagram.minimalSets(of: f) == build(minimal))
            // Each set is sorted, and the order is ascending with element 0 most significant.
            let listed = Array(diagram.setsView(of: f))
            #expect(listed.allSatisfy { $0 == $0.sorted() })
            let keys = listed.map { $0.reduce(0) { $0 | 1 << (n - 1 - $1) } }
            #expect(keys == keys.sorted())
        }
    }
}
