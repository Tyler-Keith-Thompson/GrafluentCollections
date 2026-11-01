// Exit tests, in a file of their own: each runs its body in a child process, which some platforms
// (WASI) cannot start, and those builds leave out every file holding one.

import Foundation
import GrafluentCollectionsTestSupport
import RangeTrees
import Testing
import Trees

@Suite("FenwickTree: traps")
struct FenwickTreeExitTests {
    @Test("The plain spellings trap outside the indices", .tags(.precondition))
    func plainTraps() async {
        await #expect(processExitsWith: .failure) {
            let tree: FenwickTree = [1, 2, 3]
            _ = tree.prefixSum(through: 3)
        }
        await #expect(processExitsWith: .failure) {
            let tree: FenwickTree = [1, 2, 3]
            _ = tree.prefixSum(through: -1)
        }
        await #expect(processExitsWith: .failure) {
            let tree: FenwickTree = [1, 2, 3]
            _ = tree.sum(in: 1 ..< 4)
        }
        await #expect(processExitsWith: .failure) {
            let tree: FenwickTree = [1, 2, 3]
            _ = tree.sum(in: -1 ..< 1)
        }
        await #expect(processExitsWith: .failure) {
            let tree: FenwickTree = [1, 2, 3]
            _ = tree[3]
        }
        await #expect(processExitsWith: .failure) {
            var tree: FenwickTree = [1, 2, 3]
            tree.add(1, at: 3)
        }
        await #expect(processExitsWith: .failure) {
            var tree: FenwickTree = [1, 2, 3]
            tree.add(1, at: -1)
        }
        await #expect(processExitsWith: .failure) {
            _ = FenwickTree<Int>().prefixSum(through: 0)
        }
    }

    @Test("Building or adding past Int.max traps on overflow, like the sum itself", .tags(.precondition))
    func overflowTraps() async {
        await #expect(processExitsWith: .failure) {
            _ = FenwickTree([Int.max, 1])
        }
        await #expect(processExitsWith: .failure) {
            var tree: FenwickTree = [Int.max, 0]
            tree.add(1, at: 0)
        }
    }
}
