// Exit tests, in a file of their own: each runs its body in a child process, which some platforms
// (WASI) cannot start, and those builds leave out every file holding one.

import Foundation
import GrafluentCollectionsTestSupport
import PersistentTrees
import PropertyBased
import Testing
import Trees

@Suite("PersistentTreeSet: traps")
struct PersistentTreeSetExitTests {
    @Test("Invalid indices trap", .tags(.precondition))
    func plainTraps() async {
        await #expect(processExitsWith: .failure) {
            let set: PersistentTreeSet = [1]
            _ = set[1]
        }
        await #expect(processExitsWith: .failure) {
            var set: PersistentTreeSet = [1]
            set.remove(at: 1)
        }
        await #expect(processExitsWith: .failure) {
            let dictionary: PersistentTreeDictionary = [1: "a"]
            _ = dictionary[dictionary.endIndex]
        }
        await #expect(processExitsWith: .failure) {
            _ = PersistentTreeDictionary(uniqueKeysWithValues: [(1, "a"), (1, "b")])
        }
    }
}
