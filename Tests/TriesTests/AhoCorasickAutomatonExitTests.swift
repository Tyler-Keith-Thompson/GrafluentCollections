// Exit tests, in a file of their own: each runs its body in a child process, which some platforms
// (WASI) cannot start, and those builds leave out every file holding one.

import GrafluentCollectionsTestSupport
import GraphProtocols
import PropertyBased
import Testing
import Tries

@Suite("AhoCorasickAutomaton: traps")
struct AhoCorasickAutomatonExitTests {
    @Test("The plain spellings trap outside their ranges", .tags(.precondition))
    func plainTraps() async {
        await #expect(processExitsWith: .failure) {
            let automaton = AhoCorasickAutomaton(patterns: ["ab"])
            _ = automaton.patternLength(at: 1)
        }
        await #expect(processExitsWith: .failure) {
            let automaton = AhoCorasickAutomaton(patterns: ["ab"])
            _ = automaton.statesView.symbol(ofEdgeAt: 99)
        }
        await #expect(processExitsWith: .failure) {
            let automaton = AhoCorasickAutomaton(patterns: ["ab"])
            _ = automaton.statesView.patternIndices(endingAt: 5)
        }
    }
}
