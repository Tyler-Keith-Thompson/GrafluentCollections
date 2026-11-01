// Exit tests, in a file of their own: each runs its body in a child process, which some platforms
// (WASI) cannot start, and those builds leave out every file holding one.

import BTrees
import Foundation
import GrafluentCollectionsTestSupport
import Testing
import Trees

@Suite("BTree: traps")
struct BTreeExitTests {
    @Test("The plain spellings trap outside the indices", .tags(.precondition))
    func plainTraps() async {
        await #expect(processExitsWith: .failure) {
            let tree: BTree = [1, 2, 3]
            _ = tree[3]
        }
        await #expect(processExitsWith: .failure) {
            let tree: BTree = [1, 2, 3]
            _ = tree[-1]
        }
        await #expect(processExitsWith: .failure) {
            var tree: BTree = [1, 2, 3]
            tree.remove(at: 3)
        }
        await #expect(processExitsWith: .failure) {
            var tree = BTree<Int>()
            tree.remove(at: 0)
        }
    }
}
