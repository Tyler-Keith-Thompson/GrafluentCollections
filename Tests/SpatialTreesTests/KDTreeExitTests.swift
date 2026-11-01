// Exit tests, in a file of their own: each runs its body in a child process, which some platforms
// (WASI) cannot start, and those builds leave out every file holding one.

import GrafluentCollectionsTestSupport
import PropertyBased
import SpatialTrees
import Testing
import Trees

@Suite("KDTree: traps")
struct KDTreeExitTests {
    @Test("NaN coordinates, positions out of range and inverted boxes trap", .tags(.precondition))
    func plainTraps() async {
        await #expect(processExitsWith: .failure) {
            _ = KDTree<SIMD2<Double>>([[0, .nan]])
        }
        await #expect(processExitsWith: .failure) {
            let tree: KDTree<SIMD2<Double>> = [[0, 0]]
            _ = tree[1]
        }
        await #expect(processExitsWith: .failure) {
            _ = BoundingBox<SIMD2<Double>>(lower: [1, 1], upper: [0, 2])
        }
    }
}
