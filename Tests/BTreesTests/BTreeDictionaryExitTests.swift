// Exit tests, in a file of their own: each runs its body in a child process, which some platforms
// (WASI) cannot start, and those builds leave out every file holding one.

import BTrees
import Foundation
import GrafluentCollectionsTestSupport
import Testing
import Trees

@Suite("BTreeDictionary: traps")
struct BTreeDictionaryExitTests {
    @Test("The plain spellings trap on duplicate keys and invalid indices", .tags(.precondition))
    func plainTraps() async {
        await #expect(processExitsWith: .failure) {
            _ = BTreeDictionary(uniqueKeysWithValues: [(1, "a"), (1, "b")])
        }
        await #expect(processExitsWith: .failure) {
            let dictionary: BTreeDictionary = [1: "a", 1: "b"]
            _ = dictionary.count
        }
        await #expect(processExitsWith: .failure) {
            let dictionary: BTreeDictionary = [1: "a"]
            _ = dictionary[dictionary.endIndex]
        }
        await #expect(processExitsWith: .failure) {
            var dictionary: BTreeDictionary = [1: "a"]
            dictionary.remove(at: dictionary.endIndex)
        }
    }
}
