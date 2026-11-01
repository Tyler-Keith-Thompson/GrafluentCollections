// Exit tests, in a file of their own: each runs its body in a child process, which some platforms
// (WASI) cannot start, and those builds leave out every file holding one.

import GrafluentCollectionsTestSupport
import GraphProtocols
import PropertyBased
import SuffixStructures
import Testing
import Trees

@Suite("SuffixTree: traps")
struct SuffixTreeExitTests {
    @Test("Reading a node outside the tree, or the root's edge, traps", .tags(.precondition))
    func plainTraps() async {
        await #expect(processExitsWith: .failure) {
            let tree = SuffixTree("ab")
            _ = tree.children(of: tree.nodeCount)
        }
        await #expect(processExitsWith: .failure) {
            let tree = SuffixTree("ab")
            _ = tree.edgeLabel(of: 0)
        }
        await #expect(processExitsWith: .failure) {
            let tree = SuffixTree("ab")
            _ = tree.stringDepth(of: -1)
        }
    }
}
