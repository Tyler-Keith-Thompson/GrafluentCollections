import Benchmark
import DecisionDiagrams

let benchmarks: @Sendable () -> Void = {
    Benchmark.defaultConfiguration.metrics = [.wallClock, .mallocCountTotal, .instructions]
    Benchmark.defaultConfiguration.maxDuration = .seconds(2)

    // Two queens on cells (i, j) and (k, l) of an n×n board attack each other.
    func attacks(_ i: Int, _ j: Int, _ k: Int, _ l: Int) -> Bool {
        i == k || j == l || i - j == k - l || i + j == k + l
    }

    // The n-queens problem as one function of n² variables, x(i, j) at index i·n + j: a queen in
    // every row, and none attacking another.
    func queens(_ n: Int) -> (BinaryDecisionDiagram, BinaryDecisionDiagram.Function) {
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
        return (diagram, board)
    }

    // The hand-written form at a size it can reach: every assignment of the 16 cells of a 4×4
    // board, checked directly.
    Benchmark("DecisionDiagrams: BASELINE truth table of 4 queens") { benchmark in
        for _ in benchmark.scaledIterations {
            let n = 4
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
            blackHole(solutions)
        }
    }

    Benchmark("DecisionDiagrams: BinaryDecisionDiagram for 4 queens") { benchmark in
        for _ in benchmark.scaledIterations {
            let (diagram, board) = queens(4)
            blackHole(diagram.satisfyingAssignmentCount(of: board))
        }
    }

    Benchmark("DecisionDiagrams: BinaryDecisionDiagram for 8 queens") { benchmark in
        for _ in benchmark.scaledIterations {
            let (diagram, board) = queens(8)
            blackHole(diagram.satisfyingAssignmentCount(of: board))
        }
    }

    Benchmark("DecisionDiagrams: BinaryDecisionDiagram.satisfyingAssignmentCount(of:) for 8 queens") { benchmark in
        let (diagram, board) = queens(8)
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            blackHole(diagram.satisfyingAssignmentCount(of: board))
        }
        benchmark.stopMeasurement()
    }

    // The least a compaction does: copy a table's three arrays of vertex fields, here as many
    // vertices as the 8-queens table holds before it is collected.
    Benchmark("DecisionDiagrams: BASELINE copying an 8-queens table's vertex arrays") { benchmark in
        let (diagram, _) = queens(8)
        let count = diagram.tableVertexCount
        let variables = [Int32](repeating: 1, count: count)
        let lows = [Int32](repeating: 0, count: count)
        let highs = [Int32](repeating: 1, count: count)
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            var copied = [Int32]()
            copied.reserveCapacity(3 * count)
            for v in 0 ..< count {
                copied.append(variables[v])
                copied.append(lows[v])
                copied.append(highs[v])
            }
            blackHole(copied)
        }
        benchmark.stopMeasurement()
    }

    Benchmark("DecisionDiagrams: BinaryDecisionDiagram.collectGarbage(keeping:) after 8 queens") { benchmark in
        let (diagram, board) = queens(8)
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            var collected = diagram
            blackHole(collected.collectGarbage(keeping: [board]))
        }
        benchmark.stopMeasurement()
    }

    // The independent sets of a path of n vertices: every subset, less those holding both ends of
    // an edge.
    func pathIndependentSets(_ n: Int) -> (ZeroSuppressedDecisionDiagram, ZeroSuppressedDecisionDiagram.Family) {
        var diagram = ZeroSuppressedDecisionDiagram(elementCount: n)
        var sets = diagram.unit
        for v in 0 ..< n {
            sets = diagram.join(sets, diagram.union(diagram.unit, diagram.single(v)))
        }
        for v in 0 ..< n - 1 {
            let adjacent = diagram.including(v, in: diagram.including(v + 1, in: sets))
            sets = diagram.subtracting(adjacent, from: sets)
        }
        return (diagram, sets)
    }

    // The hand-written form: every subset of a 20-vertex path as a bit mask, checked for two
    // adjacent vertices.
    Benchmark("DecisionDiagrams: BASELINE brute-force independent sets of a 20-vertex path") { benchmark in
        for _ in benchmark.scaledIterations {
            let n = 20
            var count = 0
            for mask in 0 ..< 1 << n where mask & (mask >> 1) == 0 {
                count += 1
            }
            blackHole(count)
        }
    }

    Benchmark("DecisionDiagrams: ZeroSuppressedDecisionDiagram independent sets of a 20-vertex path") { benchmark in
        for _ in benchmark.scaledIterations {
            let (diagram, sets) = pathIndependentSets(20)
            blackHole(diagram.count(of: sets))
        }
    }

    Benchmark("DecisionDiagrams: ZeroSuppressedDecisionDiagram independent sets of a 200-vertex path") { benchmark in
        for _ in benchmark.scaledIterations {
            let (diagram, sets) = pathIndependentSets(200)
            blackHole(diagram.count(of: sets))
        }
    }
}
