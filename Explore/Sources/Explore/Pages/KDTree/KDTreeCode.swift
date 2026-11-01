// snippet: kdtree-imports
import SpatialTrees
import Trees
// snippet end

// The k-d tree and quadtree page's code. The marked regions are its code panel.

/// One query of the page: the point nearest a spot, or the points inside a box.
enum SpatialQuery: Equatable {
    case nearest(SIMD2<Double>)
    case box(BoundingBox<SIMD2<Double>>)
}

/// The points in `text`: `x,y` pairs from 0 to 100, separated by spaces; at most 24.
func spatialPoints(_ text: String) -> [SIMD2<Double>] {
    let points = text.split(separator: " ").compactMap { token -> SIMD2<Double>? in
        let parts = token.split(separator: ",").compactMap { Double($0) }
        guard parts.count == 2, (0 ... 100).contains(parts[0]), (0 ... 100).contains(parts[1]) else { return nil }
        return SIMD2(parts[0], parts[1])
    }
    return Array(points.prefix(24))
}

/// The queries in `text`: `?x,y` for the point nearest (x, y), `x1,y1:x2,y2` for the points in
/// the box between those corners. Coordinates run from 0 to 100; others are skipped. At most 16.
func spatialQueries(_ text: String) -> [SpatialQuery] {
    func point(_ part: Substring) -> SIMD2<Double>? {
        let parts = part.split(separator: ",").compactMap { Double($0) }
        guard parts.count == 2, (0 ... 100).contains(parts[0]), (0 ... 100).contains(parts[1]) else { return nil }
        return SIMD2(parts[0], parts[1])
    }
    var queries: [SpatialQuery] = []
    for token in text.split(separator: " ") {
        if token.first == "?", let spot = point(token.dropFirst()) {
            queries.append(.nearest(spot))
        } else if let colon = token.firstIndex(of: ":"), let a = point(token[..<colon]), let b = point(token[token.index(after: colon)...]),
                  a.x < b.x, a.y < b.y {
            queries.append(.box(BoundingBox(lower: a, upper: b)))
        }
    }
    return Array(queries.prefix(16))
}

/// Each query's answer from both structures, as point indices.
func spatialAnswers(_ points: [SIMD2<Double>], _ queries: [SpatialQuery]) -> (kd: [[Int]], quad: [[Int]]) {
    // snippet: kdtree-run
    let kd = KDTree(points)
    var quad = Quadtree<Int>(bounds: BoundingBox(lower: [0, 0], upper: [100, 100]), bucketCapacity: 2)
    for (index, point) in points.enumerated() {
        quad.insert(index, at: point)
    }
    var kdAnswers: [[Int]] = [], quadAnswers: [[Int]] = []
    for query in queries {
        switch query {
        case .nearest(let spot):
            kdAnswers.append(kd.nearestIndex(to: spot).map { [$0] } ?? [])
            quadAnswers.append(quad.nearest(to: spot).map { [$0.element] } ?? [])
        case .box(let box):
            kdAnswers.append(kd.indices(in: box))
            quadAnswers.append(quad.items(in: box).map(\.element))
        }
    }
    let cells = RootedTree(quad).vertexCount  // →
    // snippet end
    _ = cells
    return (kdAnswers, quadAnswers)
}

/// The k-d tree's shape, and the quadtree's cells.
func spatialShapes(_ points: [SIMD2<Double>]) -> (kd: BinaryTree<Int>?, quad: RootedTree<Int>) {
    // snippet: kdtree-shapes
    let kd = BinaryTree(KDTree(points))  // vertex i is points[i]
    var quad = Quadtree<Int>(bounds: BoundingBox(lower: [0, 0], upper: [100, 100]), bucketCapacity: 2)
    for (index, point) in points.enumerated() {
        quad.insert(index, at: point)
    }
    let cells = RootedTree(quad)  // cell 0 is the whole square
    let depth = kd?.height  // →
    // snippet end
    _ = depth
    return (kd, cells)
}
