// Exit tests, in a file of their own: each runs its body in a child process, which some platforms
// (WASI) cannot start, and those builds leave out every file holding one.

import DecisionDiagrams
import GrafluentCollectionsTestSupport
import GraphProtocols
import PropertyBased
import Testing

@Suite("BinaryDecisionDiagram: traps")
struct BinaryDecisionDiagramExitTests {
    @Test("Variables out of range, short assignments and functions from a larger table trap", .tags(.precondition))
    func plainTraps() async {
        await #expect(processExitsWith: .failure) {
            var diagram = BinaryDecisionDiagram(variableCount: 2)
            _ = diagram.variable(2)
        }
        await #expect(processExitsWith: .failure) {
            var diagram = BinaryDecisionDiagram(variableCount: 2)
            let x0 = diagram.variable(0)
            _ = diagram.restrict(x0, variable: 5, to: true)
        }
        await #expect(processExitsWith: .failure) {
            var diagram = BinaryDecisionDiagram(variableCount: 2)
            let x0 = diagram.variable(0)
            _ = diagram.evaluate(x0, at: [true])
        }
        await #expect(processExitsWith: .failure) {
            var big = BinaryDecisionDiagram(variableCount: 4)
            let f = big.and(big.variable(2), big.variable(3))
            let small = BinaryDecisionDiagram(variableCount: 4)
            _ = small.vertexCount(of: f)
        }
        await #expect(processExitsWith: .failure) {
            _ = BinaryDecisionDiagram.Operator(truthTable: 16)
        }
    }
}
