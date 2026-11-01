// Exit tests, in a file of their own: each runs its body in a child process, which some platforms
// (WASI) cannot start, and those builds leave out every file holding one.

import Foundation
import GrafluentCollectionsTestSupport
import Testing
import Tries
import Trees

@Suite("TrieDictionary: traps")
struct TrieDictionaryExitTests {
    @Test("The plain spelling traps on a repeated key", .tags(.precondition))
    func plainTraps() async {
        await #expect(processExitsWith: .failure) {
            _ = TrieDictionary(uniqueKeysWithValues: [("a", 1), ("a", 2)])
        }
    }
}
