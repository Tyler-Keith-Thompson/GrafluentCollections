// Exit tests, in a file of their own: each runs its body in a child process, which some platforms
// (WASI) cannot start, and those builds leave out every file holding one.

import GrafluentCollectionsTestSupport
import SpatialTrees
import Testing

@Suite("MXCIFQuadtree and MXCIFOctree: traps")
struct MXCIFQuadtreeExitTests {
    @Test("Boxes reaching outside the bounds trap", .tags(.precondition))
    func plainTraps() async {
        await #expect(processExitsWith: .failure) {
            var tree = MXCIFQuadtree<Int>(bounds: BoundingBox(lower: [0, 0], upper: [1, 1]))
            tree.insert(0, in: BoundingBox(lower: [0.5, 0.5], upper: [1.5, 1]))
        }
        await #expect(processExitsWith: .failure) {
            var space = MXCIFOctree<Int>(bounds: BoundingBox(lower: [0, 0, 0], upper: [1, 1, 1]))
            space.insert(0, in: BoundingBox(lower: [-0.1, 0, 0], upper: [0.5, 0.5, 0.5]))
        }
    }
}
