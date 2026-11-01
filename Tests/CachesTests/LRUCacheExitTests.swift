// Exit tests, in a file of their own: each runs its body in a child process, which some platforms
// (WASI) cannot start, and those builds leave out every file holding one.

import Caches
import GrafluentCollectionsTestSupport
import PropertyBased
import Testing
import Trees

@Suite("LRUCache: traps")
struct LRUCacheExitTests {
    @Test("A negative capacity traps", .tags(.precondition))
    func plainTraps() async {
        await #expect(processExitsWith: .failure) {
            _ = LRUCache<Int, Int>(capacity: -1)
        }
    }
}
