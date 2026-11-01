// Exit tests, in a file of their own: each runs its body in a child process, which some platforms
// (WASI) cannot start, and those builds leave out every file holding one.

import GrafluentCollectionsTestSupport
import PropertyBased
import Ropes
import Testing
import Trees

@Suite("Rope: traps")
struct RopeExitTests {
    @Test("Offsets and ranges out of bounds trap", .tags(.precondition))
    func plainTraps() async {
        await #expect(processExitsWith: .failure) {
            let rope: Rope = [1, 2, 3]
            _ = rope[3]
        }
        await #expect(processExitsWith: .failure) {
            var rope: Rope = [1, 2, 3]
            rope.insert(0, at: 4)
        }
        await #expect(processExitsWith: .failure) {
            var rope: Rope = [1, 2, 3]
            rope.removeSubrange(2 ..< 4)
        }
        await #expect(processExitsWith: .failure) {
            let rope: Rope = [1, 2, 3]
            _ = rope.extracting(1 ..< 5)
        }
        await #expect(processExitsWith: .failure) {
            var rope: Rope = [1, 2, 3]
            rope[-1] = 0
        }
    }
}
