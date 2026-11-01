// Exit tests, in a file of their own: each runs its body in a child process, which some platforms
// (WASI) cannot start, and those builds leave out every file holding one.

import DecisionDiagrams
import GrafluentCollectionsTestSupport
import GraphProtocols
import PropertyBased
import Testing

@Suite("ZeroSuppressedDecisionDiagram: traps")
struct ZeroSuppressedDecisionDiagramExitTests {
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

    @Test("Collecting garbage keeping a family from a larger table traps", .tags(.precondition))
    func collectGarbageForeignFamilyTraps() async {
        await #expect(processExitsWith: .failure) {
            var big = ZeroSuppressedDecisionDiagram(elementCount: 4)
            let f = big.family([[2, 3], [1]])
            var small = ZeroSuppressedDecisionDiagram(elementCount: 4)
            _ = small.collectGarbage(keeping: [f])
        }
    }
}
