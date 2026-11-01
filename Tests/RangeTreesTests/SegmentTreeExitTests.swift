// Exit tests, in a file of their own: each runs its body in a child process, which some platforms
// (WASI) cannot start, and those builds leave out every file holding one.

import GrafluentCollectionsTestSupport
import RangeTrees
import Testing
import Trees

@Suite("SegmentTree: traps")
struct SegmentTreeExitTests {
    @Test("Out-of-range indices and ranges, and a predicate false for the identity, trap", .tags(.precondition))
    func plainTraps() async {
        await #expect(processExitsWith: .failure) {
            let tree: SegmentTree<Sum<Int>> = [1, 2, 3]
            _ = tree.combined(in: 1 ..< 4)
        }
        await #expect(processExitsWith: .failure) {
            let tree: SegmentTree<Sum<Int>> = [1, 2, 3]
            _ = tree[3]
        }
        await #expect(processExitsWith: .failure) {
            var tree: SegmentTree<Sum<Int>> = [1, 2, 3]
            tree.update(at: -1, to: 0)
        }
        await #expect(processExitsWith: .failure) {
            let tree: SegmentTree<Sum<Int>> = [1, 2, 3]
            _ = tree.maxRight(from: 0) { $0 > 0 }
        }
        await #expect(processExitsWith: .failure) {
            let tree: SegmentTree<Sum<Int>> = [1, 2, 3]
            _ = tree.minLeft(upTo: 4) { _ in true }
        }
    }
}

@Suite("LazySegmentTree: traps")
struct LazySegmentTreeExitTests {
    @Test("Out-of-range indices and ranges trap", .tags(.precondition))
    func plainTraps() async {
        enum AddToSum: MonoidAction {
            typealias Values = Sum<Int>
            static var identity: Int { 0 }
            static func compose(_ outer: Int, _ inner: Int) -> Int { outer + inner }
            static func apply(_ update: Int, to sum: Int, count: Int) -> Int { sum + update * count }
        }
        await #expect(processExitsWith: .failure) {
            var tree: LazySegmentTree<AddToSum> = [1, 2, 3]
            tree.apply(1, in: 0 ..< 4)
        }
        await #expect(processExitsWith: .failure) {
            let tree: LazySegmentTree<AddToSum> = [1, 2, 3]
            _ = tree.combined(in: -1 ..< 2)
        }
        await #expect(processExitsWith: .failure) {
            let tree: LazySegmentTree<AddToSum> = [1, 2, 3]
            _ = tree[-1]
        }
        await #expect(processExitsWith: .failure) {
            var tree: LazySegmentTree<AddToSum> = [1, 2, 3]
            tree.update(at: 3, to: 0)
        }
    }
}
