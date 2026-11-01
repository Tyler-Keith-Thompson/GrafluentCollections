// Tests for MXCIFQuadtree and MXCIFOctree. Each test builds its own tree and checks it against a
// hand-worked answer or a brute-force scan over the same boxes, so it can be copied into another
// file and still run. Nothing here is shared but the imports.

import GrafluentCollectionsTestSupport
import PropertyBased
import SpatialTrees
import Testing
import Trees

@Suite("MXCIFQuadtree and MXCIFOctree: hand-worked cases")
struct MXCIFQuadtreeTests {
    @Test("A floor plan: containing, overlapping and pairwise searches")
    func floorPlan() {
        var plan = MXCIFQuadtree<String>(bounds: BoundingBox(lower: [0, 0], upper: [100, 100]))
        plan.insert("hall", in: BoundingBox(lower: [10, 10], upper: [60, 20]))
        plan.insert("office", in: BoundingBox(lower: [10, 20], upper: [30, 40]))
        plan.insert("garden", in: BoundingBox(lower: [70, 70], upper: [90, 90]))
        let hall = ["hall"]
        #expect(plan.items(containing: [20, 15]).map(\.element) == hall)
        let both: Set = ["hall", "office"]
        #expect(Set(plan.items(containing: [20, 20]).map(\.element)) == both)
        #expect(Set(plan.items(overlapping: BoundingBox(lower: [25, 18], upper: [35, 25])).map(\.element)) == both)
        let garden = ["garden"]
        #expect(plan.items(overlapping: BoundingBox(lower: [85, 50], upper: [100, 75])).map(\.element) == garden)
        let pairs = plan.overlappingPairs()
        let one = 1
        #expect(pairs.count == one)
        let pair = pairs.first.map { Set([$0.first.element, $0.second.element]) }
        #expect(pair == both)
        let three = 3
        #expect(plan.count == three)
    }

    @Test("A box hangs on the deepest cell that wholly contains it; one across a centre line stays above it")
    func placement() {
        var tree = MXCIFQuadtree<Int>(bounds: BoundingBox(lower: [0, 0], upper: [8, 8]))
        let rootOnly = 1
        #expect(RootedTree(tree).vertexCount == rootOnly)
        // Across the root's centre on both axes: it stays at the root, and no cell is made.
        tree.insert(0, in: BoundingBox(lower: [3, 3], upper: [5, 5]))
        #expect(RootedTree(tree).vertexCount == rootOnly)
        // Inside the lower-left quadrant [0, 4]², across its centre at 2: one level of cells.
        tree.insert(1, in: BoundingBox(lower: [1, 1], upper: [3, 3]))
        let oneLevel = 5
        #expect(RootedTree(tree).vertexCount == oneLevel)
        // Inside [0, 2]² and then [0, 1]²: two more levels.
        tree.insert(2, in: BoundingBox(lower: [0.25, 0.25], upper: [0.5, 0.5]))
        let threeLevels = 13
        #expect(RootedTree(tree).vertexCount == threeLevels)
        // Removing it frees the two levels made for it.
        #expect(tree.remove(2, in: BoundingBox(lower: [0.25, 0.25], upper: [0.5, 0.5])) == 2)
        #expect(RootedTree(tree).vertexCount == oneLevel)
        #expect(tree.remove(1, in: BoundingBox(lower: [1, 1], upper: [3, 3])) == 1)
        #expect(RootedTree(tree).vertexCount == rootOnly)
        let remaining = [0]
        #expect(tree.map(\.element) == remaining)
    }

    @Test("A box whose lower edge lies on a centre line belongs to the upper quadrant, and touching boxes overlap")
    func boundaries() {
        var tree = MXCIFQuadtree<Int>(bounds: BoundingBox(lower: [0, 0], upper: [8, 8]))
        // Lower edge on x = 4: wholly in the upper-x half, found from either side of the line.
        tree.insert(0, in: BoundingBox(lower: [4, 1], upper: [6, 2]))
        // Upper edge on x = 4: reaches the line, so it stays at the root.
        tree.insert(1, in: BoundingBox(lower: [2, 1], upper: [4, 2]))
        // The whole bounds, and a single point at the far corner.
        tree.insert(2, in: BoundingBox(lower: [0, 0], upper: [8, 8]))
        tree.insert(3, in: BoundingBox(lower: [8, 8], upper: [8, 8]))
        let onLine: Set = [0, 1, 2]
        #expect(Set(tree.items(containing: [4, 1.5]).map(\.element)) == onLine)
        let corner: Set = [2, 3]
        #expect(Set(tree.items(containing: [8, 8]).map(\.element)) == corner)
        let lineQuery = BoundingBox<SIMD2<Double>>(lower: [4, 0], upper: [4, 8])
        #expect(Set(tree.items(overlapping: lineQuery).map(\.element)) == onLine)
        func key(_ pair: OverlappingPair<SIMD2<Double>, Int>) -> [Int] {
            [pair.first.element, pair.second.element].sorted()
        }
        let pairs: Set<[Int]> = [[0, 1], [0, 2], [1, 2], [2, 3]]
        let found = tree.overlappingPairs().map(key)
        #expect(Set(found) == pairs)
        #expect(found.count == pairs.count)
        #expect(tree.items(containing: [9, 1]).isEmpty)
    }

    @Test("An empty tree and a tree of one: searches find nothing and the one, removals of absent boxes return nil")
    func emptyAndOne() {
        var tree = MXCIFQuadtree<Int>(bounds: BoundingBox(lower: [0, 0], upper: [1, 1]))
        #expect(tree.isEmpty)
        #expect(tree.items(containing: [0.5, 0.5]).isEmpty)
        #expect(tree.items(overlapping: tree.bounds).isEmpty)
        #expect(tree.overlappingPairs().isEmpty)
        #expect(tree.remove(0, in: BoundingBox(lower: [0, 0], upper: [0.1, 0.1])) == nil)
        let box = BoundingBox<SIMD2<Double>>(lower: [0.1, 0.1], upper: [0.2, 0.2])
        tree.insert(7, in: box)
        let seven = [7]
        #expect(tree.items(containing: [0.15, 0.15]).map(\.element) == seven)
        #expect(tree.overlappingPairs().isEmpty)
        #expect(tree.remove(8, in: box) == nil)
        #expect(tree.remove(7, in: BoundingBox(lower: [0.1, 0.1], upper: [0.3, 0.2])) == nil)
        #expect(tree.remove(7, in: BoundingBox(lower: [2, 2], upper: [3, 3])) == nil)
        #expect(tree.remove(in: box) { $0 > 5 } == 7)
        #expect(tree.isEmpty)
        let rootOnly = 1
        #expect(RootedTree(tree).vertexCount == rootOnly)
    }

    @Test("Equal boxes share a cell and are removed one at a time, by element")
    func equalBoxes() {
        var tree = MXCIFQuadtree<Int>(bounds: BoundingBox(lower: [0, 0], upper: [4, 4]))
        let box = BoundingBox<SIMD2<Double>>(lower: [1, 1], upper: [1.5, 1.5])
        for k in 0 ..< 4 {
            tree.insert(k, in: box)
        }
        let six = 6
        #expect(tree.overlappingPairs().count == six)
        #expect(tree.remove(2, in: box) == 2)
        let rest: Set = [0, 1, 3]
        #expect(Set(tree.items(containing: [1.25, 1.25]).map(\.element)) == rest)
        let three = 3
        #expect(tree.overlappingPairs().count == three)
    }

    @Test("Box containment and intersection include the faces")
    func boundingBoxRelations() {
        let outer = BoundingBox<SIMD2<Double>>(lower: [0, 0], upper: [4, 4])
        let inner = BoundingBox<SIMD2<Double>>(lower: [0, 1], upper: [4, 2])
        let touching = BoundingBox<SIMD2<Double>>(lower: [4, 4], upper: [5, 5])
        let apart = BoundingBox<SIMD2<Double>>(lower: [4.5, 0], upper: [5, 1])
        #expect(outer.contains(inner))
        #expect(outer.contains(outer))
        #expect(!inner.contains(outer))
        #expect(!outer.contains(touching))
        #expect(outer.intersects(touching))
        #expect(touching.intersects(outer))
        #expect(!outer.intersects(apart))
        #expect(inner.intersects(outer))
    }

    @Test("An octree: boxes across a centre plane, containing and pairwise searches, and its cells as a RootedTree")
    func octree() {
        var space = MXCIFOctree<Int>(bounds: BoundingBox(lower: [0, 0, 0], upper: [1, 1, 1]))
        space.insert(1, in: BoundingBox(lower: [0.1, 0.1, 0.1], upper: [0.6, 0.2, 0.2]))
        space.insert(2, in: BoundingBox(lower: [0.5, 0.1, 0.1], upper: [0.9, 0.3, 0.3]))
        space.insert(3, in: BoundingBox(lower: [0.1, 0.1, 0.6], upper: [0.2, 0.2, 0.7]))
        let one = 1
        #expect(space.overlappingPairs().count == one)
        let both: Set = [1, 2]
        #expect(Set(space.items(containing: [0.55, 0.15, 0.15]).map(\.element)) == both)
        let three = [3]
        #expect(space.items(overlapping: BoundingBox(lower: [0, 0, 0.5], upper: [1, 1, 1])).map(\.element) == three)
        // Box 2 makes the root's octants; box 3 lies in octant 4 of the root and octant 0 of that,
        // which makes eight more.
        let cells = 17
        #expect(RootedTree(space).vertexCount == cells)
    }

    @Test("The checked spelling throws OutOfBounds and changes nothing")
    func checkedSpelling() throws {
        var tree = MXCIFQuadtree<Int>(bounds: BoundingBox(lower: [0, 0], upper: [1, 1]))
        #expect(throws: OutOfBounds()) { try tree.insert(0, checkedIn: BoundingBox(lower: [0.5, 0.5], upper: [1.5, 1])) }
        #expect(throws: OutOfBounds()) { try tree.insert(0, checkedIn: BoundingBox(lower: [-1, -1], upper: [-0.5, -0.5])) }
        #expect(tree.isEmpty)
        try tree.insert(0, checkedIn: BoundingBox(lower: [0, 0], upper: [1, 1]))
        let one = 1
        #expect(tree.count == one)
        var space = MXCIFOctree<Int>(bounds: BoundingBox(lower: [0, 0, 0], upper: [1, 1, 1]))
        #expect(throws: OutOfBounds()) { try space.insert(0, checkedIn: BoundingBox(lower: [0, 0, 0], upper: [1, 1, 1.1])) }
        #expect(space.isEmpty)
    }
}

@Suite("MXCIFQuadtree: properties")
struct MXCIFQuadtreePropertyTests {
    @Test("After random inserts and removes, containing, overlapping and pairwise searches match brute force", .tags(.randomized))
    func matchesBruteForce() async {
        let operations = Gen.int(in: 0 ... 100_000_000).array(of: 0 ... 120)
        let queries = Gen.int(in: 0 ... 100_000_000).array(of: 1 ... 10)
        await propertyCheck(count: 200, input: operations, queries) { operations, queries in
            var tree = MXCIFQuadtree<Int>(bounds: BoundingBox(lower: [0, 0], upper: [16, 16]))
            var reference: [(box: BoundingBox<SIMD2<Double>>, element: Int)] = []
            for (serial, operation) in operations.enumerated() {
                // Corners on a coarse grid, so boxes share faces, sit on centre lines and repeat.
                let x = Double(operation % 17), y = Double(operation / 17 % 17)
                let width = Double(operation / 289 % 5), height = Double(operation / 1_445 % 5)
                let box = BoundingBox<SIMD2<Double>>(lower: [x, y], upper: [min(16, x + width), min(16, y + height)])
                if operation / 7_225 % 3 == 0, let index = reference.firstIndex(where: { $0.box == box }) {
                    let removed = reference.remove(at: index).element
                    #expect(tree.remove(removed, in: box) == removed)
                } else {
                    tree.insert(serial, in: box)
                    reference.append((box, serial))
                }
            }
            #expect(tree.count == reference.count)
            #expect(Set(tree.map(\.element)) == Set(reference.map(\.element)))
            for query in queries {
                let point = SIMD2<Double>(Double(query % 33) / 2, Double(query / 33 % 33) / 2)
                #expect(Set(tree.items(containing: point).map(\.element)) == Set(reference.filter { $0.box.contains(point) }.map(\.element)))
                let size = Double(query / 1_089 % 6)
                let box = BoundingBox(lower: point, upper: point + [size, size / 2])
                #expect(Set(tree.items(overlapping: box).map(\.element)) == Set(reference.filter { $0.box.intersects(box) }.map(\.element)))
            }
            var expected: [[Int]] = []
            for i in reference.indices {
                for j in reference.indices where j > i && reference[i].box.intersects(reference[j].box) {
                    expected.append([reference[i].element, reference[j].element].sorted())
                }
            }
            let found = tree.overlappingPairs().map { [$0.first.element, $0.second.element].sorted() }
            #expect(found.sorted { $0.lexicographicallyPrecedes($1) } == expected.sorted { $0.lexicographicallyPrecedes($1) })
        }
    }
}
