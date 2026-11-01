// The 4-queens problem as a binary decision diagram against checking every assignment of its 16
// cells. The diagram is built by a few hundred applications of operators to small diagrams and
// the truth table checks 2¹⁶ assignments, so the diagram must be at least 20× faster; the gap
// measured on a laptop is about 140×, so the bound leaves room for a busy machine. The two sides
// are timed in alternating rounds, each keeping its fastest of seven. The timing runs only in an
// optimized build; a debug build checks that both count the two solutions.

import DecisionDiagrams
import Testing

@Suite("BinaryDecisionDiagram against a truth table")
struct BinaryDecisionDiagramRatioTests {
    @Test("BinaryDecisionDiagram: 4 queens is at least 20× faster than checking every assignment", .timeLimit(.minutes(1)))
    func queensBeatTruthTable() async {
        await Task {
            let n = 4
            func attacks(_ i: Int, _ j: Int, _ k: Int, _ l: Int) -> Bool {
                i == k || j == l || i - j == k - l || i + j == k + l
            }
            func library() -> Int {
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
                return Int(diagram.satisfyingAssignmentCount(of: board))
            }
            func baseline() -> Int {
                var solutions = 0
                for bits in 0 ..< 1 << (n * n) {
                    var valid = true
                    for i in 0 ..< n where valid {
                        var row = false
                        for j in 0 ..< n where bits >> (i * n + j) & 1 == 1 {
                            row = true
                            for k in 0 ..< n {
                                for l in 0 ..< n where (k, l) != (i, j) && attacks(i, j, k, l) && bits >> (k * n + l) & 1 == 1 {
                                    valid = false
                                }
                            }
                        }
                        if !row { valid = false }
                    }
                    if valid { solutions += 1 }
                }
                return solutions
            }
            let two = 2
            #expect(library() == two)
            #expect(baseline() == two)

            #if !DEBUG
            let clock = ContinuousClock()
            var libraryTime = Duration.seconds(1_000), baselineTime = Duration.seconds(1_000)
            var sink = 0
            for _ in 0 ..< 7 {
                libraryTime = min(libraryTime, clock.measure { sink &+= library() })
                baselineTime = min(baselineTime, clock.measure { sink &+= baseline() })
            }
            #expect(sink != -1)
            let speedup = baselineTime / libraryTime
            #expect(speedup > 20, "4 queens was only \(speedup)× faster than a truth table")
            #endif
        }.value
    }
}
