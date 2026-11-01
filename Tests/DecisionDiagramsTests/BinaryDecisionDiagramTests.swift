// Each test is self-contained: it builds its own diagrams and states its own expectations, so it
// can be copied into another file and still run. Nothing here is shared but the imports.

import DecisionDiagrams
import GrafluentCollectionsTestSupport
import GraphProtocols
import PropertyBased
import Testing

@Suite("BinaryDecisionDiagram: hand-worked cases")
struct BinaryDecisionDiagramTests {
    @Test("Bryant's odd parity of three variables has 2·3 − 1 tests and 4 satisfying assignments")
    func oddParity() {
        var diagram = BinaryDecisionDiagram(variableCount: 3)
        let x0 = diagram.variable(0), x1 = diagram.variable(1), x2 = diagram.variable(2)
        let parity = diagram.xor(diagram.xor(x0, x1), x2)
        #expect(diagram.vertexCount(of: parity) == 7)
        let four: Double = 4
        #expect(diagram.satisfyingAssignmentCount(of: parity) == four)
        let all: [Int] = [0, 1, 2]
        #expect(diagram.support(of: parity) == all)
        #expect(diagram.evaluate(parity, at: [true, false, false]))
        #expect(!diagram.evaluate(parity, at: [true, true, false]))
    }

    @Test("x0 ∧ x1 ∨ x2 tests x0 at the root, x1 on its high side and x2 below both")
    func andOr() {
        var diagram = BinaryDecisionDiagram(variableCount: 3)
        let x0 = diagram.variable(0), x1 = diagram.variable(1), x2 = diagram.variable(2)
        let f = diagram.or(diagram.and(x0, x1), x2)
        #expect(diagram.vertexCount(of: f) == 5)
        let five: Double = 5
        #expect(diagram.satisfyingAssignmentCount(of: f) == five)
        let graph = diagram.graphView
        let root = f.vertex
        #expect(graph.variable(of: root) == 0)
        let (low, high) = (graph.successors(of: root)[0], graph.successors(of: root)[1])
        #expect(graph.variable(of: low) == 2)
        #expect(graph.variable(of: high) == 1)
        #expect(graph.successors(of: high) == [low, 1])
        #expect(graph.successors(of: low) == [0, 1])
        #expect(graph.variable(of: 0) == nil)
        #expect(graph.successors(of: 1).isEmpty)
    }

    @Test("Two constructions of one function give the same root, and building it again adds no vertex")
    func canonicity() {
        var diagram = BinaryDecisionDiagram(variableCount: 2)
        let x0 = diagram.variable(0), x1 = diagram.variable(1)
        let direct = diagram.and(x0, x1)
        let deMorgan = diagram.not(diagram.or(diagram.not(x0), diagram.not(x1)))
        #expect(direct == deMorgan)
        let before = diagram.tableVertexCount
        let again = diagram.and(x1, x0)
        #expect(again == direct)
        #expect(diagram.tableVertexCount == before)
    }

    @Test("The reduction rules: one vertex per variable, none whose children are equal")
    func reductionRules() {
        var diagram = BinaryDecisionDiagram(variableCount: 2)
        let x0 = diagram.variable(0)
        #expect(diagram.variable(0) == x0)
        #expect(diagram.and(x0, x0) == x0)
        #expect(diagram.or(x0, diagram.not(x0)) == diagram.constant(true))
        #expect(diagram.and(x0, diagram.not(x0)) == diagram.constant(false))
        // (x0 ∧ x1) ∨ (x0 ∧ ¬x1) is x0: the test of x1 has equal children and goes.
        let x1 = diagram.variable(1)
        let split = diagram.or(diagram.and(x0, x1), diagram.and(x0, diagram.not(x1)))
        #expect(split == x0)
        #expect(diagram.vertexCount(of: split) == 3)
    }

    @Test("Variable order decides size: x0x1 ∨ x2x3 ∨ x4x5 has 2n + 2 vertices, x0x3 ∨ x1x4 ∨ x2x5 has 2ⁿ⁺¹")
    func variableOrder() {
        let n = 3
        var diagram = BinaryDecisionDiagram(variableCount: 2 * n)
        var adjacent = diagram.constant(false)
        var apart = diagram.constant(false)
        for i in 0 ..< n {
            let pair = diagram.and(diagram.variable(2 * i), diagram.variable(2 * i + 1))
            adjacent = diagram.or(adjacent, pair)
            let distant = diagram.and(diagram.variable(i), diagram.variable(i + n))
            apart = diagram.or(apart, distant)
        }
        #expect(diagram.vertexCount(of: adjacent) == 2 * n + 2)
        #expect(diagram.vertexCount(of: apart) == 1 << (n + 1))
        #expect(diagram.satisfyingAssignmentCount(of: adjacent) == diagram.satisfyingAssignmentCount(of: apart))
    }

    @Test("Every one of the 16 operators matches its truth table at every assignment")
    func allOperators() {
        var diagram = BinaryDecisionDiagram(variableCount: 3)
        let x0 = diagram.variable(0), x1 = diagram.variable(1), x2 = diagram.variable(2)
        let f = diagram.and(x0, x1)
        let g = diagram.xor(x1, x2)
        let named: [BinaryDecisionDiagram.Operator] = [
            .false, .nor, .converseNonimplication, .notFirst, .nonimplication, .notSecond, .xor, .nand,
            .and, .equivalence, .second, .implication, .first, .converseImplication, .or, .true,
        ]
        #expect(named.map(\.truthTable) == Array(0 ..< 16))
        for table in UInt8(0) ..< 16 {
            let op = BinaryDecisionDiagram.Operator(truthTable: table)
            #expect(BinaryDecisionDiagram.Operator { op($0, $1) } == op)
            let combined = diagram.apply(op, f, g)
            for bits in 0 ..< 8 {
                let assignment = [bits & 4 != 0, bits & 2 != 0, bits & 1 != 0]
                let expected = op(diagram.evaluate(f, at: assignment), diagram.evaluate(g, at: assignment))
                #expect(diagram.evaluate(combined, at: assignment) == expected)
            }
        }
    }

    @Test("restrict fixes one variable, and exists and forall join or meet its two restrictions")
    func restrictAndQuantify() {
        var diagram = BinaryDecisionDiagram(variableCount: 3)
        let x0 = diagram.variable(0), x1 = diagram.variable(1), x2 = diagram.variable(2)
        let f = diagram.or(diagram.and(x0, x1), x2)
        #expect(diagram.restrict(f, variable: 2, to: true) == diagram.constant(true))
        #expect(diagram.restrict(f, variable: 2, to: false) == diagram.and(x0, x1))
        #expect(diagram.restrict(f, variable: 0, to: false) == x2)
        #expect(diagram.exists([0], in: f) == diagram.or(x1, x2))
        #expect(diagram.forall([0], in: f) == x2)
        #expect(diagram.exists([0, 1, 2], in: f) == diagram.constant(true))
        #expect(diagram.forall([2], in: f) == diagram.and(x0, x1))
        let picked = diagram.ifThenElse(x0, then: x1, else: x2)
        for bits in 0 ..< 8 {
            let assignment = [bits & 4 != 0, bits & 2 != 0, bits & 1 != 0]
            #expect(diagram.evaluate(picked, at: assignment) == (assignment[0] ? assignment[1] : assignment[2]))
        }
    }

    @Test("The constants have no support, and only true has a satisfying assignment")
    func constants() {
        var diagram = BinaryDecisionDiagram(variableCount: 4)
        let truth = diagram.constant(true)
        let falsity = diagram.constant(false)
        #expect(diagram.support(of: truth).isEmpty)
        #expect(diagram.vertexCount(of: falsity) == 1)
        let sixteen: Double = 16
        #expect(diagram.satisfyingAssignmentCount(of: truth) == sixteen)
        #expect(diagram.anySatisfyingAssignment(of: falsity) == nil)
        #expect(diagram.anySatisfyingAssignment(of: truth) == [false, false, false, false])
        let x3 = diagram.variable(3)
        #expect(diagram.anySatisfyingAssignment(of: x3) == [false, false, false, true])
        let eight: Double = 8
        #expect(diagram.satisfyingAssignmentCount(of: x3) == eight)
    }

    @Test("Counts past 2⁶³ are kept as Doubles")
    func largeCounts() {
        var diagram = BinaryDecisionDiagram(variableCount: 100)
        let x99 = diagram.variable(99)
        let half = Double(sign: .plus, exponent: 99, significand: 1)
        #expect(diagram.satisfyingAssignmentCount(of: x99) == half)
    }

    @Test("The graph view has a low and a high edge per test, from the vertex to its children")
    func graphView() {
        var diagram = BinaryDecisionDiagram(variableCount: 2)
        let f = diagram.or(diagram.variable(0), diagram.variable(1))
        let graph = diagram.graphView
        #expect(graph.vertexCount == diagram.tableVertexCount)
        #expect(graph.edgeCount == 2 * (graph.vertexCount - 2))
        #expect(Array(graph.edges).count == graph.edgeCount)
        for vertex in graph.vertices {
            for (k, position) in graph.outEdges(of: vertex).enumerated() {
                #expect(graph.source(ofEdgeAt: position) == vertex)
                #expect(graph.isHighEdge(at: position) == (k == 1))
            }
        }
        #expect(graph.variable(of: f.vertex) == 0)
    }

    @Test("Six queens fit on a 6×6 board in exactly four ways")
    func sixQueens() {
        let n = 6
        func attacks(_ i: Int, _ j: Int, _ k: Int, _ l: Int) -> Bool {
            i == k || j == l || i - j == k - l || i + j == k + l
        }
        var diagram = BinaryDecisionDiagram(variableCount: n * n)
        var board = diagram.constant(true)
        for i in 0 ..< n {
            var row = diagram.constant(false)
            for j in 0 ..< n {
                row = diagram.or(row, diagram.variable(i * n + j))
            }
            board = diagram.and(board, row)
        }
        for i in 0 ..< n {
            for j in 0 ..< n {
                var safe = diagram.constant(true)
                for k in 0 ..< n {
                    for l in 0 ..< n where (k, l) != (i, j) && attacks(i, j, k, l) {
                        safe = diagram.and(safe, diagram.not(diagram.variable(k * n + l)))
                    }
                }
                board = diagram.and(board, diagram.implies(diagram.variable(i * n + j), safe))
            }
        }
        let four: Double = 4
        #expect(diagram.satisfyingAssignmentCount(of: board) == four)
        let lookups = diagram.computedTableStatistics.lookups
        #expect(lookups > 0 && diagram.computedTableStatistics.hits <= lookups)
        if let solution = diagram.anySatisfyingAssignment(of: board) {
            #expect(solution.filter { $0 }.count == n)
        }
    }

    @Test("The checked spelling throws IndexOutOfRange for a variable index out of range")
    func checkedThrows() throws {
        var diagram = BinaryDecisionDiagram(variableCount: 2)
        let x1 = try diagram.variable(checked: 1)
        #expect(x1 == diagram.variable(1))
        #expect(throws: IndexOutOfRange()) { try diagram.variable(checked: 2) }
        #expect(throws: IndexOutOfRange()) { try diagram.variable(checked: -1) }
    }

}

@Suite("BinaryDecisionDiagram: properties")
struct BinaryDecisionDiagramPropertyTests {
    @Test("Random formulas match their truth tables in value, count, support, restriction and quantification", .tags(.randomized))
    func randomFormulas() async {
        // A formula is a straight-line program over five variables: each step applies one of the
        // sixteen operators to two earlier steps.
        let steps = Gen.int(in: 0 ... 1_000_000).array(of: 3 ... 24)
        await propertyCheck(count: 200, input: steps) { steps in
            let n = 5
            var diagram = BinaryDecisionDiagram(variableCount: n)
            var functions = (0 ..< n).map { diagram.variable($0) }
            var tables: [[Bool]] = (0 ..< n).map { variable in
                (0 ..< 1 << n).map { bits in bits >> (n - 1 - variable) & 1 == 1 }
            }
            for step in steps {
                let op = BinaryDecisionDiagram.Operator(truthTable: UInt8(step % 16))
                let left = (step / 16) % functions.count
                let right = (step / 1_024) % functions.count
                functions.append(diagram.apply(op, functions[left], functions[right]))
                tables.append(zip(tables[left], tables[right]).map { op($0, $1) })
            }
            let f = functions.last!
            let table = tables.last!
            func assignment(_ bits: Int) -> [Bool] {
                (0 ..< n).map { bits >> (n - 1 - $0) & 1 == 1 }
            }
            #expect((0 ..< 1 << n).allSatisfy { diagram.evaluate(f, at: assignment($0)) == table[$0] })
            #expect(diagram.satisfyingAssignmentCount(of: f) == Double(table.filter { $0 }.count))
            let dependsOn = (0 ..< n).filter { variable in
                (0 ..< 1 << n).contains { bits in table[bits] != table[bits ^ (1 << (n - 1 - variable))] }
            }
            #expect(diagram.support(of: f) == dependsOn)
            if let witness = diagram.anySatisfyingAssignment(of: f) {
                #expect(diagram.evaluate(f, at: witness))
            } else {
                #expect(!table.contains(true))
            }
            let variable = steps[0] % n
            let mask = 1 << (n - 1 - variable)
            let fixed = diagram.restrict(f, variable: variable, to: true)
            let some = diagram.exists([variable], in: f)
            let every = diagram.forall([variable], in: f)
            for bits in 0 ..< 1 << n {
                let (low, high) = (table[bits & ~mask], table[bits | mask])
                #expect(diagram.evaluate(fixed, at: assignment(bits)) == high)
                #expect(diagram.evaluate(some, at: assignment(bits)) == (low || high))
                #expect(diagram.evaluate(every, at: assignment(bits)) == (low && high))
            }
            // Canonicity: rebuilding the function from its truth table as a sum of minterms gives
            // the same root.
            var sum = diagram.constant(false)
            for bits in 0 ..< 1 << n where table[bits] {
                var term = diagram.constant(true)
                for v in 0 ..< n {
                    let x = diagram.variable(v)
                    term = diagram.and(term, bits >> (n - 1 - v) & 1 == 1 ? x : diagram.not(x))
                }
                sum = diagram.or(sum, term)
            }
            #expect(sum == f)
        }
    }

    @Test("satisfyingAssignmentCount matches brute force over up to twelve variables", .tags(.randomized))
    func countsMatchBruteForce() async {
        let clauses = Gen.int(in: 0 ... 1_000_000).array(of: 1 ... 8)
        await propertyCheck(count: 60, input: clauses) { clauses in
            // A conjunction of three-literal clauses over twelve variables.
            let n = 12
            var diagram = BinaryDecisionDiagram(variableCount: n)
            var f = diagram.constant(true)
            var literals: [[(variable: Int, positive: Bool)]] = []
            for clause in clauses {
                let picked = [(clause % n, clause & 1 == 0), ((clause / 12) % n, clause & 2 == 0), ((clause / 144) % n, clause & 4 == 0)]
                literals.append(picked.map { (variable: $0.0, positive: $0.1) })
                var disjunction = diagram.constant(false)
                for (variable, positive) in picked {
                    let x = diagram.variable(variable)
                    disjunction = diagram.or(disjunction, positive ? x : diagram.not(x))
                }
                f = diagram.and(f, disjunction)
            }
            var count = 0
            for bits in 0 ..< 1 << n {
                let satisfied = literals.allSatisfy { clause in
                    clause.contains { (bits >> $0.variable & 1 == 1) == $0.positive }
                }
                if satisfied { count += 1 }
            }
            #expect(diagram.satisfyingAssignmentCount(of: f) == Double(count))
        }
    }
}
