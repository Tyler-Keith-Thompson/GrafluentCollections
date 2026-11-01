// Exit tests, in a file of their own: each runs its body in a child process, which some platforms
// (WASI) cannot start, and those builds leave out every file holding one.

import GrafluentCollectionsTestSupport
import GraphProtocols
import PropertyBased
import SuffixStructures
import Testing
import Trees

@Suite("SuffixAutomaton: traps")
struct SuffixAutomatonExitTests {
    @Test("Reading a transition or state outside the automaton traps", .tags(.precondition))
    func plainTraps() async {
        await #expect(processExitsWith: .failure) {
            let automaton = SuffixAutomaton("ab")
            _ = automaton.transitionsView.symbol(ofEdgeAt: automaton.transitionCount)
        }
        await #expect(processExitsWith: .failure) {
            let automaton = SuffixAutomaton("ab")
            _ = automaton.transitionsView.length(of: -1)
        }
    }
}
