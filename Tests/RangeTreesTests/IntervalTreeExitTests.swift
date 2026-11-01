// Exit tests, in a file of their own: each runs its body in a child process, which some platforms
// (WASI) cannot start, and those builds leave out every file holding one.

import GrafluentCollectionsTestSupport
import PropertyBased
import RangeTrees
import Testing
import Trees

@Suite("IntervalTree: traps")
struct IntervalTreeExitTests {
    @Test("Empty intervals and positions out of range trap", .tags(.precondition))
    func plainTraps() async {
        await #expect(processExitsWith: .failure) {
            var tree = IntervalTree<Int, Int>()
            tree.insert(5 ..< 5, value: 0)
        }
        await #expect(processExitsWith: .failure) {
            _ = IntervalTree<Int, Int>([.init(range: 1 ..< 1, value: 0)])
        }
        await #expect(processExitsWith: .failure) {
            let tree = IntervalTree<Int, Int>([.init(range: 0 ..< 1, value: 0)])
            _ = tree[1]
        }
    }
}
