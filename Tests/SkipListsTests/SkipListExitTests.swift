// Exit tests, in a file of their own: each runs its body in a child process, which some platforms
// (WASI) cannot start, and those builds leave out every file holding one.

import Foundation
import GrafluentCollectionsTestSupport
import GraphProtocols
import SkipLists
import Testing

@Suite("SkipList: traps")
struct SkipListExitTests {
    @Test("The plain spellings trap outside the indices", .tags(.precondition))
    func plainTraps() async {
        await #expect(processExitsWith: .failure) {
            let list: SkipList = [1, 2, 3]
            _ = list[3]
        }
        await #expect(processExitsWith: .failure) {
            let list: SkipList = [1, 2, 3]
            _ = list[-1]
        }
        await #expect(processExitsWith: .failure) {
            var list: SkipList = [1, 2, 3]
            list.remove(at: 3)
        }
        await #expect(processExitsWith: .failure) {
            var list = SkipList<Int>()
            list.remove(at: 0)
        }
    }
}
