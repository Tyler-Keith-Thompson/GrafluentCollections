// Exit tests, in a file of their own: each runs its body in a child process, which some platforms
// (WASI) cannot start, and those builds leave out every file holding one.

import BinarySearchTrees
import Foundation
import GrafluentCollectionsTestSupport
import Testing
import Trees

@Suite("Treap: traps")
struct TreapExitTests {
    @Test("The plain spellings trap outside the indices", .tags(.precondition))
    func plainTraps() async {
        await #expect(processExitsWith: .failure) {
            let treap: Treap = [1, 2, 3]
            _ = treap[3]
        }
        await #expect(processExitsWith: .failure) {
            let treap: Treap = [1, 2, 3]
            _ = treap[-1]
        }
        await #expect(processExitsWith: .failure) {
            var treap: Treap = [1, 2, 3]
            treap.remove(at: 3)
        }
        await #expect(processExitsWith: .failure) {
            var treap = Treap<Int>()
            treap.remove(at: 0)
        }
    }
}
