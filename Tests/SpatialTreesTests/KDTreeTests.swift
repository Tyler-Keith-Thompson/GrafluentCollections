// Tests for KDTree. Each test builds its own tree and checks it against a hand-worked answer or a
// brute-force scan over the same points, so it can be copied into another file and still run.
// Nothing here is shared but the imports.

import GrafluentCollectionsTestSupport
import PropertyBased
import SpatialTrees
import Testing
import Trees

@Suite("KDTree: hand-worked cases")
struct KDTreeTests {
    @Test("Bentley's six points: nearest, k nearest, radius and box searches")
    func handWorked() {
        let tree = KDTree<SIMD2<Double>>([[2, 3], [5, 4], [9, 6], [4, 7], [8, 1], [7, 2]])
        let nearest: Int? = 4
        #expect(tree.nearestIndex(to: [9, 2]) == nearest)
        let two = [4, 5], three = [1, 3], box = [0, 1]
        #expect(tree.nearestIndices(to: [9, 2], count: 2) == two)
        #expect(tree.indices(within: 3, of: [5, 5]) == three)
        #expect(tree.indices(in: BoundingBox(lower: [0, 0], upper: [5, 5])) == box)
        let point: SIMD2<Double> = [9, 6]
        #expect(tree[2] == point)
        let six = 6
        #expect(tree.count == six)
    }

    @Test("The shape splits on x at the root, then on y, with the medians of each side")
    func shape() throws {
        let tree = KDTree<SIMD2<Double>>([[2, 3], [5, 4], [9, 6], [4, 7], [8, 1], [7, 2]])
        let shape = try #require(BinaryTree(tree))
        // [7, 2] at the root; [5, 4] and [9, 6] below; [2, 3], [4, 7] under the first and [8, 1]
        // under the second.
        let root = 5
        #expect(shape.root == root)
        let left: Int? = 1, right: Int? = 2
        #expect(shape.left(of: 5) == left)
        #expect(shape.right(of: 5) == right)
        let zero: Int? = 0, three: Int? = 3, four: Int? = 4, none: Int? = nil
        #expect(shape.left(of: 1) == zero)
        #expect(shape.right(of: 1) == three)
        #expect(shape.left(of: 2) == four)
        #expect(shape.right(of: 2) == none)
        #expect(BinaryTree(KDTree<SIMD2<Double>>()) == nil)
    }

    @Test("Duplicate points are all found, and ties go to the smaller index")
    func duplicates() {
        let tree = KDTree<SIMD2<Double>>([[1, 1], [0, 0], [1, 1], [1, 1], [3, 3]])
        let first: Int? = 0
        #expect(tree.nearestIndex(to: [1, 1]) == first)
        let copies = [0, 2, 3]
        #expect(tree.indices(within: 0, of: [1, 1]) == copies)
        #expect(tree.nearestIndices(to: [1.1, 1.1], count: 3) == copies)
    }

    @Test("Points on one line split degenerately and are still found")
    func collinear() {
        let points: [SIMD2<Float>] = (0 ..< 50).map { [Float($0 % 7), 0] }
        let tree = KDTree(points)
        let atThree = (0 ..< 50).filter { $0 % 7 == 3 }
        #expect(tree.indices(within: 0, of: [3, 0]) == atThree)
        let nearest: Int? = 3
        #expect(tree.nearestIndex(to: [3.2, 5]) == nearest)
        let box = (0 ..< 50).filter { (2 ... 4).contains($0 % 7) }
        #expect(tree.indices(in: BoundingBox(lower: [2, -1], upper: [4, 1])) == box)
    }

    @Test("Asking for more neighbours than points gives them all; zero or negative gives none")
    func countBeyondSize() {
        let tree = KDTree<SIMD3<Double>>([[0, 0, 0], [1, 0, 0], [0, 2, 0]])
        let all = [0, 1, 2], none: [Int] = []
        #expect(tree.nearestIndices(to: [0, 0, 0], count: 10) == all)
        #expect(tree.nearestIndices(to: [0, 0, 0], count: 0) == none)
        #expect(tree.nearestIndices(to: [0, 0, 0], count: -1) == none)
        #expect(tree.indices(within: -1, of: [0, 0, 0]) == none)
    }

    @Test("An empty tree finds nothing; a NaN query finds nothing")
    func emptyAndNaN() {
        let empty = KDTree<SIMD2<Double>>()
        let none: Int? = nil, nothing: [Int] = []
        #expect(empty.nearestIndex(to: [0, 0]) == none)
        #expect(empty.nearestIndices(to: [0, 0], count: 3) == nothing)
        #expect(empty.indices(within: 1, of: [0, 0]) == nothing)
        #expect(empty.isEmpty)
        let tree: KDTree<SIMD2<Double>> = [[0, 0], [1, 1]]
        #expect(tree.nearestIndex(to: [.nan, 0]) == none)
        #expect(tree.indices(within: .nan, of: [0, 0]) == nothing)
    }

    @Test("The checked spellings throw NotANumber, EmptyRange and IndexOutOfRange")
    func checkedSpellings() throws {
        #expect(throws: NotANumber()) { try KDTree<SIMD2<Double>>(checked: [[0, 0], [.nan, 1]]) }
        let tree = try KDTree<SIMD2<Double>>(checked: [[0, 0], [1, 1]])
        let one: SIMD2<Double> = [1, 1]
        #expect(try tree[checked: 1] == one)
        #expect(throws: IndexOutOfRange()) { try tree[checked: 2] }
        #expect(throws: EmptyRange()) { try BoundingBox<SIMD2<Double>>(checkedLower: [1, 0], upper: [0, 1]) }
        let box = try BoundingBox<SIMD2<Double>>(checkedLower: [0, 0], upper: [0, 1])
        #expect(box.contains([0, 1]))
    }

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

@Suite("KDTree: properties")
struct KDTreePropertyTests {
    @Test("Nearest, k nearest, radius and box searches match brute force in 2D", .tags(.randomized))
    func matchesBruteForce2D() async {
        let coordinates = Gen.int(in: 0 ... 40).array(of: 0 ... 120)
        let queries = Gen.int(in: -5 ... 45).array(of: 2 ... 12)
        await propertyCheck(count: 200, input: coordinates, queries) { coordinates, queries in
            let points: [SIMD2<Double>] = stride(from: 0, to: coordinates.count - 1, by: 2).map {
                [Double(coordinates[$0]), Double(coordinates[$0 + 1])]
            }
            let tree = KDTree(points)
            func distance(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double {
                let d = a - b
                return (d * d).sum()
            }
            for k in stride(from: 0, to: queries.count - 1, by: 2) {
                let query: SIMD2<Double> = [Double(queries[k]) + 0.5, Double(queries[k + 1])]
                let ranked = points.indices.sorted {
                    (distance(points[$0], query), $0) < (distance(points[$1], query), $1)
                }
                #expect(tree.nearestIndex(to: query) == ranked.first)
                let wanted = queries[k] % 7
                #expect(tree.nearestIndices(to: query, count: wanted) == Array(ranked.prefix(max(wanted, 0))))
                let radius = Double(abs(queries[k + 1]) % 12)
                #expect(tree.indices(within: radius, of: query) == points.indices.filter { distance(points[$0], query) <= radius * radius })
                let corner = SIMD2<Double>(Double(queries[k]), Double(queries[k + 1]))
                let box = BoundingBox(lower: corner, upper: corner + [radius, 2 * radius])
                #expect(tree.indices(in: box) == points.indices.filter { box.contains(points[$0]) })
            }
            #expect(Array(tree) == points)
        }
    }

    @Test("Nearest and radius searches match brute force in 3D with Float coordinates", .tags(.randomized))
    func matchesBruteForce3D() {
        var rng = SeededRandomNumberGenerator(seed: 18)
        for _ in 0 ..< 20 {
            let points: [SIMD3<Float>] = (0 ..< Int.random(in: 0 ..< 300, using: &rng)).map { _ in
                [Float.random(in: -1 ... 1, using: &rng), Float.random(in: -1 ... 1, using: &rng), Float.random(in: -1 ... 1, using: &rng)]
            }
            let tree = KDTree(points)
            func distance(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float {
                let d = a - b
                return (d * d).sum()
            }
            for _ in 0 ..< 20 {
                let query: SIMD3<Float> = [Float.random(in: -1.2 ... 1.2, using: &rng), Float.random(in: -1.2 ... 1.2, using: &rng), Float.random(in: -1.2 ... 1.2, using: &rng)]
                let ranked = points.indices.sorted {
                    (distance(points[$0], query), $0) < (distance(points[$1], query), $1)
                }
                #expect(tree.nearestIndex(to: query) == ranked.first)
                #expect(tree.nearestIndices(to: query, count: 5) == Array(ranked.prefix(5)))
                let radius = Float.random(in: 0 ... 0.6, using: &rng)
                #expect(tree.indices(within: radius, of: query) == points.indices.filter { distance(points[$0], query) <= radius * radius })
            }
        }
    }
}
