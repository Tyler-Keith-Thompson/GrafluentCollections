// The independent sets of a 20-vertex path as a zero-suppressed decision diagram against checking
// every one of its 2²⁰ subsets. The diagram is built by a few dozen family operations on diagrams
// of about 2n vertices, so it must be at least 4× faster; the gap measured on a laptop is
// about 16×, so the bound leaves room for a busy machine. The two sides are timed in
// alternating rounds, each keeping its fastest of seven. The timing runs only in an optimized
// build; a debug build checks that both count Fibonacci(22) sets.

import DecisionDiagrams
import Testing

@Suite("ZeroSuppressedDecisionDiagram against brute force")
struct ZeroSuppressedDecisionDiagramRatioTests {
    @Test("ZeroSuppressedDecisionDiagram: a path's independent sets are at least 4× faster than checking every subset", .timeLimit(.minutes(1)))
    func pathIndependentSetsBeatBruteForce() async {
        await Task {
            let n = 20
            func library() -> Int {
                var diagram = ZeroSuppressedDecisionDiagram(elementCount: n)
                var sets = diagram.unit
                for v in 0 ..< n {
                    sets = diagram.join(sets, diagram.union(diagram.unit, diagram.single(v)))
                }
                for v in 0 ..< n - 1 {
                    let adjacent = diagram.including(v, in: diagram.including(v + 1, in: sets))
                    sets = diagram.subtracting(adjacent, from: sets)
                }
                return Int(diagram.count(of: sets))
            }
            func baseline() -> Int {
                var count = 0
                for mask in 0 ..< 1 << n where mask & (mask >> 1) == 0 {
                    count += 1
                }
                return count
            }
            let fibonacci22 = 17_711
            #expect(library() == fibonacci22)
            #expect(baseline() == fibonacci22)

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
            #expect(speedup > 4, "A path's independent sets were only \(speedup)× faster than brute force")
            #endif
        }.value
    }
}
