// Tests for Quadtree and Octree. Each test builds its own tree and checks it against a
// hand-worked answer or a brute-force scan over the same points, so it can be copied into another
// file and still run. Nothing here is shared but the imports.

import GrafluentCollectionsTestSupport
import PropertyBased
import SpatialTrees
import Testing
import Trees

@Suite("Quadtree and Octree: hand-worked cases")
struct QuadtreeTests {
    @Test("A small map: nearest, radius and box searches")
    func handWorked() {
        var map = Quadtree<String>(bounds: BoundingBox(lower: [0, 0], upper: [100, 100]))
        map.insert("café", at: [10, 20])
        map.insert("library", at: [12, 22])
        map.insert("station", at: [80, 75])
        map.insert("park", at: [50, 50])
        let cafe: String? = "café"
        #expect(map.nearest(to: [11, 19])?.element == cafe)
        let near: Set = ["café", "library"]
        #expect(Set(map.items(within: 5, of: [11, 21]).map(\.element)) == near)
        let upper: Set = ["station", "park"]
        #expect(Set(map.items(in: BoundingBox(lower: [50, 50], upper: [100, 100])).map(\.element)) == upper)
        let order = ["station", "park"]
        #expect(map.nearest(to: [70, 60], count: 2).map(\.element) == order)
        let four = 4
        #expect(map.count == four)
    }

    @Test("Splitting: a leaf over capacity splits into four, and the cells convert to a RootedTree")
    func splitsIntoQuadrants() {
        var tree = Quadtree<Int>(bounds: BoundingBox(lower: [0, 0], upper: [4, 4]), bucketCapacity: 2)
        tree.insert(0, at: [1, 1])
        tree.insert(1, at: [3, 1])
        let leafOnly = 1
        #expect(RootedTree(tree).vertexCount == leafOnly)
        tree.insert(2, at: [1, 3])
        // Three items over a capacity of two: the root splits once, one item per quadrant.
        let rootAndQuadrants = 5
        #expect(RootedTree(tree).vertexCount == rootAndQuadrants)
        tree.insert(3, at: [0.5, 0.5])
        tree.insert(4, at: [0.25, 0.25])
        // The lower-left quadrant now holds three and splits again.
        let twoLevels = 9
        #expect(RootedTree(tree).vertexCount == twoLevels)
        let all: Set = [0, 1, 2, 3, 4]
        #expect(Set(tree.map(\.element)) == all)
    }

    @Test("Points on cell boundaries and on the bounds' edges are found")
    func boundaries() {
        var tree = Quadtree<Int>(bounds: BoundingBox(lower: [0, 0], upper: [8, 8]), bucketCapacity: 1)
        let points: [SIMD2<Double>] = [[4, 4], [0, 0], [8, 8], [4, 0], [0, 4], [8, 4], [2, 6]]
        for (k, point) in points.enumerated() {
            tree.insert(k, at: point)
        }
        for (k, point) in points.enumerated() {
            let one = [k]
            #expect(tree.items(within: 0, of: point).map(\.element) == one)
            #expect(tree.items(in: BoundingBox(lower: point, upper: point)).map(\.element) == one)
        }
        let centreLine: Set = [0, 3, 5]
        #expect(Set(tree.items(in: BoundingBox(lower: [4, 0], upper: [8, 4])).map(\.element)) == centreLine)
    }

    @Test("Many coincident points stop splitting at the depth limit and are all found")
    func coincidentPoints() {
        var tree = Quadtree<Int>(bounds: BoundingBox(lower: [0, 0], upper: [1, 1]), bucketCapacity: 2)
        for k in 0 ..< 500 {
            tree.insert(k, at: [0.3, 0.7])
        }
        let fiveHundred = 500
        #expect(tree.items(within: 0, of: [0.3, 0.7]).count == fiveHundred)
        // One chain of splits down to the depth limit: four cells per level below the root.
        let cells = 1 + 4 * 24
        #expect(RootedTree(tree).vertexCount == cells)
        for k in 0 ..< 499 {
            tree.remove(k, at: [0.3, 0.7])
        }
        let last = [499]
        #expect(tree.items(within: 0, of: [0.3, 0.7]).map(\.element) == last)
        let leafOnly = 1
        #expect(RootedTree(tree).vertexCount == leafOnly)
    }

    @Test("Removal finds the element at its point, merges emptied quadrants, and leaves a copy alone")
    func removeAndCopyOnWrite() {
        var tree = Quadtree<Int>(bounds: BoundingBox(lower: [0, 0], upper: [10, 10]), bucketCapacity: 2)
        for k in 0 ..< 20 {
            tree.insert(k, at: [Double(k % 5) * 2 + 0.5, Double(k / 5) * 2 + 0.5])
        }
        let copy = tree
        let seven: Int? = 7, missing: Int? = nil
        #expect(tree.remove(7, at: [4.5, 2.5]) == seven)
        #expect(tree.remove(7, at: [4.5, 2.5]) == missing)
        #expect(tree.remove(at: [9, 9]) { _ in true } == missing)
        let nineteen = 19, twenty = 20
        #expect(tree.count == nineteen)
        #expect(copy.count == twenty)
        #expect(tree.items(within: 0.1, of: [4.5, 2.5]).isEmpty)
        let stillThere = [7]
        #expect(copy.items(within: 0.1, of: [4.5, 2.5]).map(\.element) == stillThere)
        for k in 0 ..< 20 where k != 7 {
            tree.remove(k, at: [Double(k % 5) * 2 + 0.5, Double(k / 5) * 2 + 0.5])
        }
        #expect(tree.isEmpty)
        let leafOnly = 1
        #expect(RootedTree(tree).vertexCount == leafOnly)
        tree.insert(1, at: [1, 1])
        let one = [1]
        #expect(tree.map(\.element) == one)
    }

    @Test("An octree splits into eight and finds nearest points in space")
    func octree() {
        var space = Octree<Int>(bounds: BoundingBox(lower: [0, 0, 0], upper: [1, 1, 1]), bucketCapacity: 1)
        space.insert(1, at: [0.1, 0.1, 0.1])
        space.insert(2, at: [0.9, 0.9, 0.9])
        let one: Int? = 1
        #expect(space.nearest(to: [0.2, 0.2, 0.2])?.element == one)
        let rootAndOctants = 9
        #expect(RootedTree(space).vertexCount == rootAndOctants)
        let both: Set = [1, 2]
        #expect(Set(space.items(within: 2, of: [0.5, 0.5, 0.5]).map(\.element)) == both)
        let two: Int? = 2
        #expect(space.remove(2, at: [0.9, 0.9, 0.9]) == two)
        let leafOnly = 1
        #expect(RootedTree(space).vertexCount == leafOnly)
    }

    @Test("Empty trees, NaN queries and a negative radius find nothing")
    func emptyAndDegenerateQueries() {
        let tree = Quadtree<Int>(bounds: BoundingBox(lower: [0, 0], upper: [1, 1]))
        #expect(tree.nearest(to: [0.5, 0.5]) == nil)
        #expect(tree.nearest(to: [0.5, 0.5], count: 3).isEmpty)
        var one = tree
        one.insert(0, at: [0.5, 0.5])
        #expect(one.nearest(to: [.nan, 0]) == nil)
        #expect(one.items(within: -1, of: [0.5, 0.5]).isEmpty)
        #expect(one.nearest(to: [0, 0], count: 0).isEmpty)
        let all = [0]
        #expect(one.nearest(to: [0, 0], count: 5).map(\.element) == all)
    }

    @Test("The checked spelling throws OutOfBounds and changes nothing")
    func checkedSpelling() throws {
        var tree = Quadtree<Int>(bounds: BoundingBox(lower: [0, 0], upper: [1, 1]))
        #expect(throws: OutOfBounds()) { try tree.insert(0, checkedAt: [1.5, 0]) }
        #expect(throws: OutOfBounds()) { try tree.insert(0, checkedAt: [.nan, 0]) }
        #expect(tree.isEmpty)
        try tree.insert(0, checkedAt: [1, 1])
        let one = 1
        #expect(tree.count == one)
        var space = Octree<Int>(bounds: BoundingBox(lower: [0, 0, 0], upper: [1, 1, 1]))
        #expect(throws: OutOfBounds()) { try space.insert(0, checkedAt: [0, 0, -0.1]) }
    }

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

@Suite("Quadtree: properties")
struct QuadtreePropertyTests {
    @Test("After random inserts and removes, box, radius and nearest searches match brute force", .tags(.randomized))
    func matchesBruteForce() async {
        let operations = Gen.int(in: 0 ... 1_000_000).array(of: 0 ... 150)
        let queries = Gen.int(in: 0 ... 1_000_000).array(of: 1 ... 10)
        await propertyCheck(count: 200, input: operations, queries) { operations, queries in
            var tree = Quadtree<Int>(bounds: BoundingBox(lower: [0, 0], upper: [16, 16]), bucketCapacity: 3)
            var reference: [(point: SIMD2<Double>, element: Int)] = []
            for (serial, operation) in operations.enumerated() {
                // Coordinates on a coarse grid so points coincide and sit on cell boundaries.
                let point = SIMD2<Double>(Double(operation % 17), Double(operation / 17 % 17))
                if operation / 289 % 3 == 0, let index = reference.firstIndex(where: { $0.point == point }) {
                    let removed = reference.remove(at: index).element
                    #expect(tree.remove(removed, at: point) == removed)
                } else {
                    tree.insert(serial, at: point)
                    reference.append((point, serial))
                }
            }
            #expect(tree.count == reference.count)
            #expect(Set(tree.map(\.element)) == Set(reference.map(\.element)))
            func distance(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double {
                let d = a - b
                return (d * d).sum()
            }
            for query in queries {
                let center = SIMD2<Double>(Double(query % 170) / 10, Double(query / 170 % 170) / 10)
                let radius = Double(query / 28_900 % 6)
                #expect(Set(tree.items(within: radius, of: center).map(\.element)) == Set(reference.filter { distance($0.point, center) <= radius * radius }.map(\.element)))
                let box = BoundingBox(lower: center, upper: center + [radius, 2 * radius])
                #expect(Set(tree.items(in: box).map(\.element)) == Set(reference.filter { box.contains($0.point) }.map(\.element)))
                let wanted = query % 5
                let found = tree.nearest(to: center, count: wanted).map { distance($0.point, center) }
                let distances = reference.map { distance($0.point, center) }.sorted()
                #expect(found == Array(distances.prefix(wanted)))
                #expect(tree.nearest(to: center).map { distance($0.point, center) } == distances.first)
            }
        }
    }
}
