// Exit tests, in a file of their own: each runs its body in a child process, which some platforms
// (WASI) cannot start, and those builds leave out every file holding one.

import GrafluentCollectionsTestSupport
import PropertyBased
import SpatialTrees
import Testing
import Trees

@Suite("Quadtree and Octree: traps")
struct QuadtreeExitTests {
    @Test("Points outside the bounds and a bucket capacity below one trap", .tags(.precondition))
    func plainTraps() async {
        await #expect(processExitsWith: .failure) {
            var tree = Quadtree<Int>(bounds: BoundingBox(lower: [0, 0], upper: [1, 1]))
            tree.insert(0, at: [2, 0])
        }
        await #expect(processExitsWith: .failure) {
            _ = Quadtree<Int>(bounds: BoundingBox(lower: [0, 0], upper: [1, 1]), bucketCapacity: 0)
        }
        await #expect(processExitsWith: .failure) {
            var space = Octree<Int>(bounds: BoundingBox(lower: [0, 0, 0], upper: [1, 1, 1]))
            space.insert(0, at: [0, 0, 2])
        }
    }
}
