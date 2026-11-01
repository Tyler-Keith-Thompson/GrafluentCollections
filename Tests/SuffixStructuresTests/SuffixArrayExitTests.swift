// Exit tests, in a file of their own: each runs its body in a child process, which some platforms
// (WASI) cannot start, and those builds leave out every file holding one.

import GrafluentCollectionsTestSupport
import PropertyBased
import SuffixStructures
import Testing

@Suite("SuffixArray: traps")
struct SuffixArrayExitTests {
    @Test("Reading a position or prefix length outside the arrays traps", .tags(.precondition))
    func plainTraps() async {
        await #expect(processExitsWith: .failure) {
            let text = SuffixArray("ab")
            _ = text.positions[2]
        }
        await #expect(processExitsWith: .failure) {
            let text = SuffixArray("ab")
            _ = text.longestCommonPrefixes[-1]
        }
    }
}
